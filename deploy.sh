#!/bin/bash
set -e

APP_DIR=/srv/labpng
SERVICE_NAME=labpng

sudo mkdir -p $APP_DIR
sudo chown alalfy:alalfy $APP_DIR

rsync -a --delete \
    --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
    --exclude='k8s' --exclude='.github' --exclude='Dockerfile' \
    --exclude='deploy.sh' \
    ./ $APP_DIR/

cd $APP_DIR

export PATH="$APP_DIR/venv/bin:$PATH"

if [ ! -d venv ]; then
    python3 -m venv venv
fi

pip install --quiet -r requirements.txt

ORT_VER=$(pip show onnxruntime 2>/dev/null | sed -n 's/^Version: //p')

if [ ! -f "/srv/onnxruntime-build-$ORT_VER/.done" ]; then
    sudo apt-get install -y -qq build-essential cmake protobuf-compiler git
    sudo rm -rf /srv/onnxruntime-build-$ORT_VER
    git clone --depth 1 --branch v$ORT_VER \
        https://github.com/microsoft/onnxruntime.git \
        /srv/onnxruntime-build-$ORT_VER
    cd /srv/onnxruntime-build-$ORT_VER
    ./build.sh --config Release --build_dir build --skip_tests --parallel \
        --cmake_extra_defines onnxruntime_ENABLE_AVX=OFF onnxruntime_ENABLE_AVX2=OFF \
        --allow_running_as_root
    touch .done
    cd $APP_DIR
    sudo apt-get purge -y build-essential cmake protobuf-compiler git
    sudo apt-get autoremove -y -qq
fi

pip install --quiet /srv/onnxruntime-build-$ORT_VER/build/dist/onnxruntime-*.whl --force-reinstall --no-deps

sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<UNIT
[Unit]
Description=LabPNG
After=network.target

[Service]
Type=simple
User=alalfy
WorkingDirectory=$APP_DIR
Environment=REMBG_CACHE_DIR=$APP_DIR/.rembg
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 1 --threads 10 --timeout 90 --bind 0.0.0.0:8000 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME
