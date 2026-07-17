FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN python -c "from rembg import new_session; new_session('u2netp')"

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
