import asyncio
import logging
import subprocess
import uvicorn
from dataclasses import dataclass
from datetime import datetime, timedelta, UTC
from enum import Enum
from os import environ
from random import choice as random_choice
from sys import platform
from typing import Annotated

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status, Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import jwt
from jose.exceptions import JWTError, JWTClaimsError, ExpiredSignatureError
from pymongo.mongo_client import MongoClient
from pydantic import BaseModel
from passlib.context import CryptContext


load_dotenv(".env", override=True)


DB_URI = environ["DB_URI"]
JWT_SECRET_KEY = environ["JWT_SECRET_KEY"]


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
    character: str = "cactus"


class UserInDB(User):
    hashed_password: str


class Token(BaseModel):
    access_token: str


@dataclass
class Player:
    websocket: WebSocket
    user: User


app = FastAPI()
database = MongoClient(DB_URI).database
crypt_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
logging.basicConfig(level=logging.DEBUG, format="%(levelname)s:     %(message)s")


def get_user_with_username(username: str) -> UserInDB | None:
    user_as_dict = database.users.find_one({"username": username})
    if user_as_dict:
        return UserInDB(**user_as_dict)


def create_access_token(username: str, expires_in: timedelta) -> Token:
    expiration_time = (datetime.now(UTC) + expires_in).timestamp()
    token_data = {"sub": username, "exp": expiration_time}
    encoded_token = jwt.encode(token_data, JWT_SECRET_KEY)
    return Token(access_token=encoded_token)


@app.post("/login", status_code=status.HTTP_201_CREATED, tags=["auth"])
async def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> Token:
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
    
    return create_access_token(user.username, timedelta(weeks=1))


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


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="access-token")


def get_user_with_token(token: str) -> UserInDB:
    try:
        token_data =jwt.decode(token, JWT_SECRET_KEY)
        username = token_data["sub"]
        user = get_user_with_username(username)
        return user # type: ignore (User can't be None because tokens are created only for existing users)
    except (JWTError, ExpiredSignatureError, JWTClaimsError):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, 
            "Invalid token. Please login again.", 
            {"WWW-Authenticate": "Bearer"}
        )


async def get_authenticated_user(access_token: Annotated[str, Depends(oauth2_scheme)]) -> UserInDB:
    return get_user_with_token(access_token)


@app.get("/me", tags=["users"])
async def read_user_me(user: Annotated[UserInDB, Depends(get_authenticated_user)]) -> User:
    return user


@app.post("/websockets-token", status_code=status.HTTP_201_CREATED, tags=["auth"])
async def create_websockets_token(user: Annotated[UserInDB, Depends(get_authenticated_user)]) -> Token:
    return create_access_token(user.username, timedelta(seconds=5))


matchmaking_pool: list[Player] = []


async def run_match_syncronizer(port: int | None = None) -> None:
    if port == None:
        port = PortsManager.get_unused()
    
    process = await asyncio.create_subprocess_exec(
        "match_syncronizer.exe" if platform == "win32" else "/code/match_syncronizer.x86_64",
        "--headless",
        f"--port={port}",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    PortsManager.release(port)
    logging.debug(f"Match syncronizer process finished with stdout: {stdout.decode()} and stderr: {stderr.decode()}")


@app.websocket("/match")
async def match(websocket: WebSocket, access_token: str) -> None:
    # If token is not valid, 401 Unauthorized exception will be raised
    user = get_user_with_token(access_token)
    
    await websocket.accept()
    
    player = Player(websocket, user)
    
    logging.debug(f"{user.username} joined the matchmaking.")
    
    if len(matchmaking_pool) > 0:
        match_players = matchmaking_pool.pop(0), player
        match_players_user = list(map(lambda player: player.user.model_dump(exclude={"hashed_password": True}), match_players))
        port = PortsManager.get_unused()
        asyncio.create_task(run_match_syncronizer(port))
        
        logging.info(f"Started new match: {player.user.username} vs {match_players[0].user.username}")
        
        for match_player in match_players:
            await match_player.websocket.send_json({
                "code": WebSocketMessageCode.OPPONENT_FOUND.value, 
                "body": {
                    "port": port,
                    "users": match_players_user,
                },
            })

    else:
        matchmaking_pool.append(player)

    try:
        # Keep the websockets connection open
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect as disconnection:
        logging.debug(f"{user.username} disconnected from match websocket with code {disconnection.code}, reason {disconnection.reason}")
        if player in matchmaking_pool:
            matchmaking_pool.remove(player)


if __name__ == '__main__' and platform == "win32":
    # There are two event loops: Selector and Proactor. Using SelectorEventLoop (the
    # default) on Windows raises "NotImplementedError" when trying to run a subprocess.
    # Running the server this way because solves the error
    
    from asyncio.windows_events import ProactorEventLoop
    
    class ProactorServer(uvicorn.Server):
        def run(self, sockets=None):
            loop = ProactorEventLoop()
            asyncio.set_event_loop(loop)
            asyncio.run(self.serve(sockets=sockets))
            
    server = ProactorServer(uvicorn.Config(app))
    server.run()
