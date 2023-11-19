FROM python:3.12.0
WORKDIR /app

# Install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Install Godot
RUN apt-get update && apt-get install -y wget unzip
RUN wget https://downloads.tuxfamily.org/godotengine/4.1.1/Godot_v4.1.1-stable_linux.x86_64.zip \
    && mkdir ~/.cache \
    && mkdir -p ~/.config/godot \
    && unzip Godot_v4.1.1-stable_linux.x86_64.zip \
    && mv Godot_v4.1.1-stable_linux.x86_64 /usr/local/bin/godot \
    && rm Godot_v4.1.1-stable_linux.x86_64.zip

# Export match_syncronizer
COPY match_syncronizer .
RUN godot --headless --export-release --path match_syncronizer "Linux" \
    && mv match_syncronizer.x86_64 /usr/local/bin/match_syncronizer

# Run server
COPY main.py .
EXPOSE 8000 49151-65535
CMD ["python", "main.py"]
