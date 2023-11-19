FROM python:3.12.0
WORKDIR /app

# Install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Install Godot
RUN wget https://github.com/godotengine/godot-builds/releases/download/4.1.1-stable/Godot_v4.1.1-stable_linux.x86_64.zip
RUN unzip Godot_v4.1.1-stable_linux.x86_64.zip
RUN mv Godot_v4.1.1-stable_linux.x86_64 godot.x86_64
RUN chmod a+x godot.x86_64

# Export match_syncronizer
COPY match_syncronizer .
RUN godot.x86_64 --headless --export-release --path match_syncronizer Linux
RUN chmod a+x match_syncronizer.x86_64

# Run server
COPY main.py .
EXPOSE 8000 49151-65535
CMD ["python", "main.py"]
