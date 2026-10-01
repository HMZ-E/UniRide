FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl openssl tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server.py push.py ./
RUN useradd --uid 10001 --create-home uniride && mkdir /data && chown uniride:uniride /data
USER uniride
EXPOSE 8787
CMD ["python3", "server.py", "--host", "0.0.0.0", "--port", "8787", "--database", "/data/uniride.sqlite3"]
