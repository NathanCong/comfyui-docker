#!/usr/bin/env bash

set -Eeuo pipefail

#
# 运行前检测
#
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/check.sh"

#
# 启动容器
#
"${COMPOSE[@]}" up -d --build
