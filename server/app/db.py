import logging

from pymongo.errors import PyMongoError
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi

from app.env import DB_URI


try:
    client = MongoClient(DB_URI, server_api=ServerApi("1"))
    client.admin.command("ping")
    db = client.database
except PyMongoError as error:
    logging.exception("Error when connecting to the DB: " + str(error))
