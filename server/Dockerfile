FROM python:3.12.0
WORKDIR /code

# Install Python packages
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Install Godot
RUN apt-get update && apt-get install -y wget unzip
RUN wget https://downloads.tuxfamily.org/godotengine/4.1.1/Godot_v4.1.1-stable_linux.x86_64.zip \
    && mkdir ~/.cache \
    && mkdir -p ~/.config/godot \
    && unzip /code/Godot_v4.1.1-stable_linux.x86_64.zip \
    && rm /code/Godot_v4.1.1-stable_linux.x86_64.zip \
    && mv /code/Godot_v4.1.1-stable_linux.x86_64 /code/godot.x86_64 \
    && chmod +x /code/godot.x86_64

# Install match_syncronizer
COPY ./match_syncronizer /code/match_syncronizer
RUN godot --path /code/match_syncronizer --headless --export-release Linux /code/match_syncronizer.x86_64
RUN chmod +x /code/match_syncronizer.x86_64

# Run server
COPY ./main.py /code/main.py
EXPOSE 8000 49151-65535
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
