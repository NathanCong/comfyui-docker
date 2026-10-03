#!/usr/bin/env bash

set -Eeuo pipefail

#
# 设置路径变量
#
# SCRIPT_DIR   脚本目录
# PROJECT_DIR  项目根目录
#
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

#
# 进入项目根目录
#
cd "${PROJECT_DIR}"

if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    echo "错误：未找到 docker compose 或 docker-compose。" >&2
    exit 1
fi
