FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y git build-essential && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir git+https://github.com/alexandersp/mtprotoproxy.git uvloop

COPY main.py /app/main.py

EXPOSE 8080

CMD ["python3", "main.py"]
