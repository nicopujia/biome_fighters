import logging
from os import environ

from jose.exceptions import JWTError, JWTClaimsError, ExpiredSignatureError
from fastapi import HTTPException, status
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi

from cryptography import decode_access_token
from models import UserInDB


class Database:
    def __init__(self) -> None:
        client = MongoClient(environ["DB_URI"], server_api=ServerApi('1'))

        try:
            client.admin.command('ping')
            logging.info("Successfully connected to database")
        except:
            logging.exception("Failed connection to database:")
            raise
        
        instance = client.get_database("database")
        self.users = instance.get_collection("users")

    def get_user_with_username(self, username: str) -> UserInDB | None:
        user_as_dict = self.users.find_one({"username": username})
        if user_as_dict:
            return UserInDB(**user_as_dict)

    def get_user_with_access_token(self, access_token: str) -> UserInDB:
        invalid_token_exception = HTTPException(status.HTTP_401_UNAUTHORIZED, headers={"WWW-Authenticate": "Bearer"})
        try:
            token_data = decode_access_token(access_token)
            username = token_data["sub"]
            user = self.get_user_with_username(username)
            return user # User can't be None because tokens are created only for existing users
        except ExpiredSignatureError:
            invalid_token_exception.detail = "Your session has expired. Please, log in again."
            raise invalid_token_exception
        except (JWTError, JWTClaimsError):
            invalid_token_exception.detail = "You aren't logged in. Please, log in."
            raise invalid_token_exception
        except:
            invalid_token_exception.detail = "You are unauthenticated error for an unknown reason."
            raise invalid_token_exception


database = Database()
