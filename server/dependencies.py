from typing import Annotated
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer

from database import database
from models import UserInDB


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="access-token")


async def get_authenticated_user(access_token: Annotated[str, Depends(oauth2_scheme)]) -> UserInDB:
    return database.get_user_with_access_token(access_token)
