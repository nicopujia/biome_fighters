import asyncio
import logging
import subprocess
import uvicorn
from dataclasses import dataclass
from datetime import datetime, timedelta, UTC
from enum import Enum
from os import environ
from random import choice as random_choice
from typing import Annotated, Self

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, WebSocketException, status, Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import jwt
from jose.exceptions import JWTError, JWTClaimsError, ExpiredSignatureError
from pymongo.mongo_client import MongoClient
from pydantic import BaseModel
from passlib.context import CryptContext


load_dotenv("./.env", override=True, verbose=True)


DB_URI: str = environ["DB_URI"]
JWT_ALGORITHM: str = environ["JWT_ALGORITHM"]
ACCESS_TOKEN_SECRET_KEY: str = environ["ACCESS_TOKEN_SECRET_KEY"]
ACCESS_TOKEN_LIFE_TIME_IN_SECONDS: int = int(environ["ACCESS_TOKEN_LIFE_TIME_IN_SECONDS"])
WS_TOKEN_SECRET_KEY: str = environ["WS_TOKEN_SECRET_KEY"]
WS_TOKEN_LIFE_TIME_IN_SECONDS: int = int(environ["WS_TOKEN_LIFE_TIME_IN_SECONDS"])


class TokenData:    
    def __init__(self, sub: str, exp: float | None = None) -> None:
        self.subject = sub
        self.expiration_time = exp
    
    def encode(self, secret_key: str) -> str:
        return jwt.encode({"sub": self.subject, "exp": self.expiration_time}, secret_key, JWT_ALGORITHM)

    @classmethod
    def decode(cls, token: str, secret_key: str) -> Self:
        try:
            return TokenData(**jwt.decode(token, secret_key, (JWT_ALGORITHM)))
        except (JWTError, ExpiredSignatureError, JWTClaimsError):
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED, 
                "Invalid token. Please login again.", 
                {"WWW-Authenticate": "Bearer"}
            )

    @staticmethod
    def calc_exp(seconds: int) -> float:
        """Calculate token expiration time from now"""
        return (datetime.now(UTC) + timedelta(seconds=seconds)).timestamp()


class PortsManager:
    used_ports: set[int] = set()
    available_ports = list(range(49151, 65536))

    @classmethod
    def get_unused(cls) -> int:
        port = random_choice(cls.available_ports)
        cls.available_ports.remove(port)
        cls.used_ports.add(port)
        return port

    @classmethod
    def release(cls, port: int) -> None:
        if port in cls.used_ports:
            cls.used_ports.remove(port)
            cls.available_ports.append(port)


class WebSocketMessageCode(Enum):
    OPPONENT_FOUND = 0


class User(BaseModel):
    username: str
    character: str = "diamond"


class UserInDB(User):
    hashed_password: str


@dataclass
class Player:
    websocket: WebSocket
    user: User


app = FastAPI()
database = MongoClient(DB_URI).database
crypt_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
logging.basicConfig(level=logging.INFO, format="%(levelname)s:     %(message)s")


def get_user_with_username(username: str) -> UserInDB | None:
    user_as_dict = database.users.find_one({"username": username})
    if user_as_dict:
        return UserInDB(**user_as_dict)


@app.post("/register", status_code=status.HTTP_201_CREATED, tags=["users"])
async def create_new_user(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> User:
    if get_user_with_username(form_data.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists. Please login"
        )
    
    hashed_password = crypt_context.hash(form_data.password)
    user = UserInDB(username=form_data.username, hashed_password=hashed_password)
    database.users.insert_one(dict(user))
    return user


@app.post("/access-token", status_code=status.HTTP_201_CREATED, tags=["auth"])
async def create_access_token(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> dict[str, str]:
    user = get_user_with_username(form_data.username)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User does not exist. Please register"
        )
    
    if not crypt_context.verify(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Wrong password"
        )
    
    token_data = TokenData(user.username, TokenData.calc_exp(ACCESS_TOKEN_LIFE_TIME_IN_SECONDS))
    return {"access_token": token_data.encode(ACCESS_TOKEN_SECRET_KEY)}


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="access-token")


def get_user_with_token(token: str, secret_key: str) -> UserInDB:
    token_data = TokenData.decode(token, secret_key)
    user = get_user_with_username(token_data.subject)    
    return user # type: ignore (because tokens are created only for existing users)


async def get_authenticated_user(access_token: Annotated[str, Depends(oauth2_scheme)]) -> UserInDB:
    return get_user_with_token(access_token, ACCESS_TOKEN_SECRET_KEY)


@app.get("/me", tags=["users"])
async def read_user_me(user: Annotated[UserInDB, Depends(get_authenticated_user)]) -> User:
    return user


@app.post("/websockets-token", status_code=status.HTTP_201_CREATED, tags=["auth"])
async def create_websockets_token(user: Annotated[UserInDB, Depends(get_authenticated_user)]) -> dict[str, str]:
    token_data = TokenData(user.username, TokenData.calc_exp(WS_TOKEN_LIFE_TIME_IN_SECONDS))
    return {"websockets_token": token_data.encode(WS_TOKEN_SECRET_KEY)}


two_players_matchmaking_pool: list[Player] = []
four_players_matchmaking_pool: list[Player] = []


async def run_match_syncronizer(port: int = 50000, players_amount: int = 2) -> None:
    process = await asyncio.create_subprocess_exec(
        "match_syncronizer",
        "--headless",
        f"--port={port}",
        f"--players_amount={players_amount}",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    PortsManager.release(port)
    logging.debug(f"Match syncronizer process finished with stdout: {stdout.decode()} and stderr: {stderr.decode()}")


@app.websocket("/match")
async def match(websocket: WebSocket, websockets_token: str, players_amount: int) -> None:
    # If token is not valid, 401 Unauthorized exception will be raised
    user = get_user_with_token(websockets_token, WS_TOKEN_SECRET_KEY)
    
    if players_amount != 2 and players_amount != 4:
        raise WebSocketException(status.WS_1003_UNSUPPORTED_DATA, "Invalid players amount. It must be either 2 or 4")

    await websocket.accept()
    
    matchmaking_pool = two_players_matchmaking_pool if players_amount == 2 else four_players_matchmaking_pool
    player = Player(websocket, user)
    matchmaking_pool.append(player)
    
    logging.info(f"{user.username} joined the matchmaking.")
    
    if len(matchmaking_pool) == players_amount:
        match_players: list[Player] = [matchmaking_pool.pop(0) for _ in range(players_amount)]
        match_players_user = list(map(lambda player: player.user.model_dump(exclude={"hashed_password": True}), match_players))
        port = PortsManager.get_unused()
        asyncio.create_task(run_match_syncronizer(port, players_amount))
        
        logging.info(f"Started new match at port {port}: {" vs ".join(map(lambda user: user["username"], match_players_user))}")
        
        for match_player in match_players:
            await match_player.websocket.send_json({
                "code": WebSocketMessageCode.OPPONENT_FOUND.value, 
                "body": {
                    "port": port,
                    "map": "valley",
                    "users": match_players_user,
                },
            })
    
    try:
        # Keep the websockets connection open
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect as disconnection:
        logging.info(f"{user.username} disconnected from match websocket with code {disconnection.code}, reason {disconnection.reason}")
        if player in matchmaking_pool:
            matchmaking_pool.remove(player)


if __name__ == '__main__':
    # There are two event loops: Selector and Proactor. Using SelectorEventLoop on
    # Windows raises "NotImplementedError" when trying to run a subprocess
    
    # I run the server this way because it solves the error
    
    class ProactorServer(uvicorn.Server):
        def run(self, sockets=None):
            loop = asyncio.ProactorEventLoop()
            asyncio.set_event_loop(loop)
            asyncio.run(self.serve(sockets=sockets))

    config = uvicorn.Config(app=app, host="0.0.0.0", port=8000)
    server = ProactorServer(config)
    server.run()
