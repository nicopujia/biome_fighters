from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi

from app.env import DB_URI


client = MongoClient(DB_URI, server_api=ServerApi("1"))


try:
    client.admin.command("ping")
    db = client.database
except Exception as error:
    print("Error when connecting to the DB:", error)
