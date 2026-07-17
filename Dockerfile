FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bake model at build time so the container doesn't download it at startup
RUN python -c "from rembg import new_session; new_session('u2netp')"

COPY . .

EXPOSE 8000

# Single worker to avoid multiplying ~50MB model memory per process.
# 10 threads for concurrent SSE connections (each blocks on sleep(2) per client).
CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
