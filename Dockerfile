FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake protobuf-compiler git \
    libgomp1 && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --recursive --depth 1 --branch v1.27.0 \
    https://github.com/microsoft/onnxruntime.git /opt/ort && \
    cd /opt/ort && \
    ./build.sh --config Release --build_dir build --skip_tests --parallel \
    --cmake_extra_defines onnxruntime_ENABLE_AVX=OFF onnxruntime_ENABLE_AVX2=OFF \
    --allow_running_as_root && \
    pip install --no-cache-dir build/dist/onnxruntime-*.whl

FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg
WORKDIR /srv

COPY --from=builder /usr/local/lib/python3.11/site-packages/ \
    /usr/local/lib/python3.11/site-packages/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
