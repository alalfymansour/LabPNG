FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt scripts/fix_execstack.py .

RUN pip install --no-cache-dir -r requirements.txt && \
    find /usr/local/lib/python3.11/site-packages -name '*.so*' \
        -exec python fix_execstack.py {} +

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
