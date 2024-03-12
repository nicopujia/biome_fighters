import asyncio
from datetime import timedelta
from enum import Enum
import logging
from dataclasses import dataclass
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status, Depends
from pathlib import Path
import random
from typing import Annotated, Self

from cryptography import encode_access_token
from database import database
from dependencies import get_authenticated_user
from models import Token, User


class PortsManager:
    used_ports: set[int] = set()
    available_ports = list(range(1024, 49151))

    @classmethod
    def get_unused(cls) -> int:
        port = random.choice(cls.available_ports)
        cls.available_ports.remove(port)
        cls.used_ports.add(port)
        return port

    @classmethod
    def release(cls, port: int) -> None:
        if port in cls.used_ports:
            cls.used_ports.remove(port)
            cls.available_ports.append(port)


@dataclass
class Player:
    websocket: WebSocket
    user: User
    opponent: Self | None = None
    
    async def send_match_data(self, port: int, player_number: int) -> None:
        if not self.opponent:
            return

        await self.websocket.send_json({
            "code": MatchMessageCode.OPPONENT_FOUND.value,
            "port": port, 
            "your_player_number": player_number,
            "opponent_user": self.opponent.user.model_dump(), 
        })


class MatchMessageCode(Enum):
    OPPONENT_FOUND = 0
    OPPONENT_LEFT = 1


router = APIRouter(prefix="/matches", tags=["matches"])
matchmaking_pool: list[Player] = []


@router.post("/access-token", tags=["auth"], status_code=status.HTTP_201_CREATED)
async def create_match_access_token(user: Annotated[User, Depends(get_authenticated_user)]) -> Token:
    return Token(access_token=encode_access_token(user.username, timedelta(seconds=5)), token_type="websocket")


@router.websocket("/play")
async def play_match(websocket: WebSocket, match_access_token: str) -> None:
    # If the access token invalid, 401 Unauthorized exception will be raised
    user = database.get_user_with_access_token(match_access_token)
    
    await websocket.accept()
    
    player = Player(websocket, user)
    
    logging.info(f"{user.username} joined the matchmaking.")
    
    if len(matchmaking_pool) > 0:
        other = matchmaking_pool.pop(0)
        await start_match(player, other)
    else:
        matchmaking_pool.append(player)

    try:
        # Keep the websockets connection open
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect as disconnection:
        logging.info(f"{user.username} disconnected from match websocket with code {disconnection.code}, reason {disconnection.reason}")
        
        # If the player disconnects with an opponent (i. e. in the middle of 
        # the match), tell the opponent that he/she has won
        if player.opponent and disconnection.code in (status.WS_1001_GOING_AWAY, status.WS_1006_ABNORMAL_CLOSURE):
            player.opponent.opponent = None
            await player.opponent.websocket.send_json({"code": MatchMessageCode.OPPONENT_LEFT.value})
        
        if player in matchmaking_pool:
            matchmaking_pool.remove(player)


async def start_match(player_1: Player, player_2: Player) -> None:
    port = PortsManager.get_unused()
    asyncio.create_task(run_match_syncronizer(port))
    
    player_1.opponent, player_2.opponent = player_2, player_1
    await player_1.send_match_data(port, 1)
    await player_2.send_match_data(port, 2)
    
    logging.info(f"New match has just started: {player_1.user.username} vs {player_2.user.username}")


async def run_match_syncronizer(port: int | None = None) -> int:
    """
    Runs match synchronizer at the specified `port` in a subprocess. 
    If no port is specified, it uses an unused port. Returns the exit code.
    """
    if port == None:
        port = PortsManager.get_unused()
    
    path = Path.cwd() / "match_synchronizer"
    print("path:",path)
    process = await asyncio.create_subprocess_exec(
        "godot", "--headless", f"--port={port}",
        cwd=path,
    )
    exit_code = await process.wait()
    PortsManager.release(port)
    print("\n")
    logging.info(f"Match syncronizer process finished with exit code {exit_code}")
    return exit_code
