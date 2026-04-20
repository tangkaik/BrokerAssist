#!/bin/bash
set -e

if [ ! -f .env ]; then
    echo "错误：.env 文件不存在，请从 .env.example 复制并配置"
    exit 1
fi

source .venv/bin/activate
exec uvicorn app.main:app --host 0.0.0.0 --port 8001
