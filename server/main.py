import asyncio
import logging
from datetime import timedelta
from dotenv import load_dotenv
from sys import platform
from typing import Annotated

import uvicorn
from fastapi import FastAPI, HTTPException, status, Depends
from fastapi.security import OAuth2PasswordRequestForm

load_dotenv()
from cryptography import encode_access_token, verify_password
from database import database
from models import Token
from routers import matches, users


logging.basicConfig(format="%(levelname)s:     %(message)s")
logging.getLogger('passlib').setLevel(logging.ERROR)
app = FastAPI()
app.include_router(matches.router)
app.include_router(users.router)


@app.post("/access-token", status_code=status.HTTP_201_CREATED, tags=["auth"])
async def create_access_token(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> Token:
    user = database.get_user_with_username(form_data.username)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User does not exist. Please register.",
        )
    
    if not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please check your username and password.",
        )
    
    access_token = encode_access_token(user.username, timedelta(weeks=4))
    return Token(access_token=access_token, token_type="bearer")


if __name__ == "__main__":
    # There are two event loops: Selector and Proactor. Using SelectorEventLoop (the
    # default) on Windows raises "NotImplementedError" when trying to run a 
    # subprocess (in this case, match_synchronizer). Running the server this way 
    # solves the error. Don't ask me why.
    
    config = uvicorn.Config(app, host="0.0.0.0", port=55555)
    
    if platform == "win32":
        from asyncio.windows_events import ProactorEventLoop
        
        class ProactorServer(uvicorn.Server):
            def run(self, sockets=None):
                loop = ProactorEventLoop()
                asyncio.set_event_loop(loop)
                asyncio.run(self.serve(sockets=sockets))
        
        server = ProactorServer(config)
    else:
        server = uvicorn.Server(config)
    
    server.run()
