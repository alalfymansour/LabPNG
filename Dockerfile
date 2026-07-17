FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt scripts/fix_execstack.py .

RUN pip install --no-cache-dir -r requirements.txt && \
    python fix_execstack.py /usr/local/lib/python3.11/site-packages/onnxruntime/capi/*.so*

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
