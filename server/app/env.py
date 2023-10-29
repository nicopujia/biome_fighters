from dotenv import load_dotenv
from os import environ


load_dotenv("app/.env")


DB_URI = environ["DB_URI"]

JWT_ALGORITHM = environ["JWT_ALGORITHM"]
JWT_SECRET_KEY = environ["JWT_SECRET_KEY"]
JWT_TOKEN_EXPIRES_IN_MINUTES = int(environ["JWT_TOKEN_EXPIRES_IN_MINUTES"])
