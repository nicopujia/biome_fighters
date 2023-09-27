from dataclasses import dataclass
from enum import Enum
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, status


app = FastAPI()


@dataclass
class Player:
    username: str
    socket: WebSocket


class MessageCode(Enum):
    OPPONENT_FOUND = 0
    SESSION_DESCRIPTION = 1
    ICE_CANDIDATE = 2


async def send_message(socket: WebSocket, code: MessageCode, data: dict[str, Any]):
    await socket.send_json({"code": code.value, "data": data})


matchmaking_queue: list[Player] = []
current_matches: dict[int, tuple[Player, Player]] = {}


@app.websocket("/{username}/match")
async def match(socket: WebSocket, username: str):
    await socket.accept()

    if username in map(lambda player: player.username, matchmaking_queue):
        return await socket.close(
            code=status.WS_1003_UNSUPPORTED_DATA,
            reason="Username already in use"
        )

    player = Player(username=username, socket=socket)
    print(username, "joined")

    if len(matchmaking_queue) == 1:
        opponent = matchmaking_queue.pop(0)
        match_id = len(current_matches)
        current_matches[match_id] = opponent, player
        print(f"New match ({match_id}): {opponent.username} vs {username}")
        print("Current matches:", current_matches)
        await send_message(
            socket,
            MessageCode.OPPONENT_FOUND,
            {"match_id": match_id,
             "is_offerer": False,
             "opponent_username": opponent.username}
        )
        await send_message(
            opponent.socket,
            MessageCode.OPPONENT_FOUND,
            {"match_id": match_id,
             "is_offerer": True,
             "opponent_username": username}
        )
    else:
        matchmaking_queue.append(player)

    print("Matchmaking queue:", matchmaking_queue)

    try:
        while True:
            json = await socket.receive_json()
            data = json["data"]
            match = current_matches[json["match_id"]]
            opponent = match[0] if match[0] != player else match[1]
            print(f"Packet received from {username}: {json}")
            print(f"Sending it to {opponent.username}")
            match json["code"]:
                case MessageCode.SESSION_DESCRIPTION.value:
                    await send_message(
                        opponent.socket,
                        MessageCode.SESSION_DESCRIPTION,
                        {"type": data["type"], "sdp": data["sdp"]}
                    )

                case MessageCode.ICE_CANDIDATE.value:
                    await send_message(
                        opponent.socket,
                        MessageCode.ICE_CANDIDATE,
                        {"media": data["media"],
                         "index": data["index"],
                         "name": data["name"]}
                    )

    except WebSocketDisconnect as error:
        print(f"{player} disconnected with code {error.code}")
        if player in matchmaking_queue:
            matchmaking_queue.remove(player)
