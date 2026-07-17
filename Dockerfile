FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends execstack && \
    rm -rf /var/lib/apt/lists/*

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    execstack -c /usr/local/lib/python3.11/site-packages/onnxruntime/capi/*.so* 2>/dev/null; \
    execstack -c /usr/local/lib/python3.11/site-packages/onnxruntime/*.so* 2>/dev/null; \
    apt-get purge -y --auto-remove execstack

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
