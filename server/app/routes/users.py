from datetime import datetime, timedelta, UTC
from typing import Annotated, Iterable

from fastapi import Depends, HTTPException, status, APIRouter
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from app.db import db
from app.env import JWT_SECRET_KEY, JWT_ALGORITHM, JWT_TOKEN_EXPIRES_IN_MINUTES


class User(BaseModel):
    username: str


class UserInDB(User):
    hashed_password: str


class Token(BaseModel):
    access_token: str


router = APIRouter(prefix="/users")
collection = db.users
crypt_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")


def get_user_by_username(username: str) -> UserInDB | None:
    user_dict = collection.find_one({"username": username})
    if user_dict:
        return UserInDB(**user_dict)


def create_access_token(username: str) -> Token:
    expire_time = datetime.now(UTC) + timedelta(minutes=JWT_TOKEN_EXPIRES_IN_MINUTES)
    data = {"sub": username, "exp": expire_time}
    encoded_data = jwt.encode(data, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return Token(access_token=encoded_data)


@router.post("/login")
async def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> Token:
    user = get_user_by_username(form_data.username)
    
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
    
    return create_access_token(user.username)


@router.post("/register")
async def register(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> Token:
    if get_user_by_username(form_data.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists. Please login"
        )
    
    hashed_password = crypt_context.hash(form_data.password)
    user = UserInDB(username=form_data.username, hashed_password=hashed_password)
    collection.insert_one(dict(user))
    
    return create_access_token(user.username)


async def get_user_with_token(token: Annotated[str, Depends(oauth2_scheme)]) -> UserInDB:
    invalid_token_error = HTTPException(
        status.HTTP_401_UNAUTHORIZED, 
        "Invalid token", 
        {"WWW-Authenticate": "Bearer"}
    )
    
    try:
        decoded_token = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        username: str = decoded_token["sub"]
        expire_time = datetime.fromtimestamp(decoded_token["exp"], UTC)
        user = get_user_by_username(username)
        
        if not user or expire_time < datetime.now(UTC):
            raise invalid_token_error
        
        return user
    
    except JWTError:
        raise invalid_token_error


@router.get("/me")
async def read_me(user: Annotated[UserInDB, Depends(get_user_with_token)]) -> User:
    return user
