FROM python:3.11-slim AS ort-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive --depth 1 --branch v1.16.3 \
    https://github.com/microsoft/onnxruntime.git /opt/ort

# GitLab regenerated Eigen archive → SHA1 mismatch. Skip hash check.
RUN sed -i '/URL_HASH/d' /opt/ort/cmake/external/eigen.cmake

WORKDIR /opt/ort
# TMPDIR on /build avoids Docker overlay rename() bug with `ar`
RUN mkdir -p /build/tmp && \
    TMPDIR=/build/tmp python tools/ci_build/build.py \
    --config Release \
    --build_dir /build \
    --skip_tests \
    --compile_no_warning_as_error \
    --parallel \
    --cmake_extra_defines \
        onnxruntime_ENABLE_AVX=OFF \
        onnxruntime_ENABLE_AVX2=OFF \
        onnxruntime_ENABLE_AVX512=OFF \
    --allow_running_as_root

RUN pip install --no-cache-dir /build/Release/dist/onnxruntime-*.whl

FROM python:3.11-slim

ENV REMBG_CACHE_DIR=/srv/rembg
WORKDIR /app

COPY --from=ort-builder /usr/local/lib/python3.11/site-packages/onnxruntime* \
    /usr/local/lib/python3.11/site-packages/

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN python -c "from rembg import new_session; new_session('u2netp')"

COPY . .
EXPOSE 8000
CMD ["gunicorn", "--workers", "1", "--threads", "10", "--timeout", "90", "--bind", "0.0.0.0:8000", "app:app"]
