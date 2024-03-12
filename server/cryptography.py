from datetime import UTC, datetime, timedelta
from os import environ
from typing import Any
from jose import jwt
from passlib.context import CryptContext


secret_key = environ["SECRET_KEY"]
crypt_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password, hashed_password) -> bool:
    return crypt_context.verify(plain_password, hashed_password)


def get_password_hash(plain_password) -> str:
    return crypt_context.hash(plain_password)


def encode_access_token(subject: str, expires_in: timedelta) -> str:
    expiration_time = (datetime.now(UTC) + expires_in).timestamp()
    data = {"sub": subject, "exp": expiration_time}
    return jwt.encode(data, secret_key)


def decode_access_token(access_token: str) -> dict[str, Any]:
    return jwt.decode(access_token, secret_key)
