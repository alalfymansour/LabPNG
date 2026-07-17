FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN python -c "import onnxruntime; print('onnx OK')" && \
    python -c "import rembg; print('rembg OK')"

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
