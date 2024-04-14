# Biome Fighters

## Overview
Biome Fighters is a 1v1 online multiplayer platform fighter game with a retro aesthetic, where there are more than just two platforms and *every corner is an opportunity for the victory*. It is inspired in [Spelunky's deatchmath](https://spelunky.fandom.com/wiki/Deathmatch_(HD)), but taken to a competitive online multiplayer environment.

Please note that the current version is prototype, so a lot of [initial ideas for the game](https://github.com/nicopujia/biome_fighters/labels/Enhancement) are not implemented. It only includes a minimal playable experience in a map with some platforms, with one biome (the desert) and one character (the cactus).

[Gameplay video](https://youtu.be/MzYI5f1HNUU?si=pvkVsRpZaRKO-gxa)

### Screenshots
![User authentication](screenshots/user_authentication.jpg)
![Main menu](screenshots/main_menu.jpg)
![Gameplay 1](screenshots/gameplay_1.jpg)
![Gameplay 2](screenshots/gameplay_2.jpg)
![End of match](screenshots/end_of_match.jpg)

### Features
- User authentication with JWTs
- Basic matchmaking
- Character movement and animations
- Punches, life points and end of fights
- Deployed on a server

### Tech stack
- **Aseprite** for the graphics.
- **Godot Engine** for the client and for the match synchronization.
- **Python** and **FastAPI** for the backend.
- **MongoDB Atlas** for the database.
- **GCP**'s Compute Engine for the deployment (*running live right now!*).

## Getting Started
To try out the game, call a friend or anyone else to play with and both of you download the client executable (for either Windows or Android) from the [releases](https://github.com/nicopujia/biome_fighters/releases/). After that, just hit the play button and try to beat each other!

If you want to run the game server locally for development, see below on the [contributions](#how-to-run-locally) section.

## Contributions
Contributions are not being actively sought at the moment, as the game is not expected to undergo significant development. 

However, if you are interested in the project, feel free to continue it by your own. Below I leave a guide to run the server locally in case you want to develop it. Besides, you can check out the [issues](https://github.com/nicopujia/biome_fighters/issues/) section to get some ideas to start with.

*(And don't forget to tell me if you do, as I would be very curious to see how the game evolves!)*

### How to run locally
1. Make sure you have these programs installed on your computer **and added to the PATH**:
    - [Git](https://www.git-scm.com/downloads)
    - [Python 3.12](https://www.python.org/downloads/release/python-3120/)
    - [Godot 4.2.1 stable](https://godotengine.org/download/archive/4.2.1-stable/)

2. Execute the following commands in the command line (if you are on Windows, do it with Git Bash and not with CMD):
```bash
# Clone the repository
git clone https://github.com/nicopujia/biome_fighters.git

# Move to the server folder
cd biome_fighters/server

# Create a Python environment
python -m venv env

# Activate the environment
source env/bin/activate # (Linux / MacOS)
source env/scripts/activate # (Windows)

# Install the dependencies
pip install -r requirements.txt

# Create the environment variables file
touch .env
```

3. Setup environment variables in `server/.env`:

    - `SECRET_KEY=<The key you generate>`: Generate a JWT secret key with the `HS256` algorithm (you can do it with [this website](https://jwt-keys.21no.de/)). 
    
    - `DB_URI="<Your database connection string>"`: Create a [MongoDB](https://www.mongodb.com/) database (either local or with MongoDB Atlas) with a cluster called `database` and paste its connection string.

4. Run the server: `python main.py`.

5. Change the flag `IS_LOCAL` to true in `client/global/api/api.gd`.

6. Run 2 (or more) instances of the client. You can achieve this by setting `Debug -> Run multiple instances -> Run 2 instances` in the Godot editor and then executing the project.

## License
This project is licensed under the [MIT License](LICENSE).

## Acknowledgments
Thank you for checking out Biome Fighters! Your interest is appreciated, and feel free to explore the prototype. Please note that this project may not see further updates.
