FROM python:3.12.0
WORKDIR /app

# Install Python packages
COPY ./requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# Install Godot
RUN apt-get update && apt-get install -y wget unzip
RUN wget https://downloads.tuxfamily.org/godotengine/4.1.1/Godot_v4.1.1-stable_linux.x86_64.zip \
    && mkdir ~/.cache \
    && mkdir -p ~/.config/godot \
    && unzip /app/Godot_v4.1.1-stable_linux.x86_64.zip \
    && mv /app/Godot_v4.1.1-stable_linux.x86_64 /usr/local/bin/godot \
    && rm /app/Godot_v4.1.1-stable_linux.x86_64.zip

# Install match_syncronizer
COPY ./match_syncronizer /app/match_syncronizer
RUN godot --path /app/match_syncronizer --headless --export-release Linux /usr/local/bin/match_syncronizer/match_syncronizer.x86_64

# Run server
COPY ./main.py /app/main.py
EXPOSE 8000 49151-65535
CMD ["python", "/app/main.py"]
