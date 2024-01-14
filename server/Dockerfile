FROM python:3.12.0
WORKDIR /code

# Install Python packages
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Install Godot dependencies
RUN apt-get update \
    && apt-get install -y build-essential scons pkg-config libx11-dev libxcursor-dev \
    libxinerama-dev libgl1-mesa-dev libglu-dev libasound2-dev \
    libpulse-dev libudev-dev libxi-dev libxrandr-dev yasm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Godot
ARG GODOT_VERSION="4.1.3"
RUN wget "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux_x86_64.zip" \
    && unzip "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" "/usr/local/bin/godot" \
    && chmod +x "/usr/local/bin/godot" \
    && rm "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"

# Export match synchronizer
COPY ./match_synchronizer /code/match_synchronizer/
RUN godot --path /code/match_synchronizer --headless --export-release Linux /code/match_synchronizer.x86_64 \
    && chmod +x /code/match_synchronizer.x86_64

# Run server
COPY ./main.py /code/main.py
EXPOSE 8000 49151-65535
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
