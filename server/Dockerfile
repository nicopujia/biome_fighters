FROM python:3.12.0
WORKDIR /code

# Install Python packages
COPY ./requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Install match_syncronizer
COPY ./match_syncronizer.x86_64 /code/match_syncronizer.x86_64
RUN chmod +x /code/match_syncronizer.x86_64

# Run server
COPY ./main.py /code/main.py
EXPOSE 8000 49151-65535
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
