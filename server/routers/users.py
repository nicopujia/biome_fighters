from typing import Annotated

from fastapi import HTTPException, status, APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm

from cryptography import get_password_hash
from database import database
from dependencies import get_authenticated_user
from models import User, UserInDB


router = APIRouter(prefix="/users", tags=["users"])


@router.post("/me", status_code=status.HTTP_201_CREATED)
async def create_new_user(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> None:
    if database.get_user_with_username(form_data.username):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User already exists. Please login or choose a different username",
        )
    hashed_password = get_password_hash(form_data.password)
    user = UserInDB(username=form_data.username, hashed_password=hashed_password)
    database.users.insert_one(dict(user))


@router.get("/me")
async def get_current_user(user: Annotated[User, Depends(get_authenticated_user)]) -> User:
    return user
