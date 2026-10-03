#!/usr/bin/env bash

set -Eeuo pipefail

#
# 运行前检测
#
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/check.sh"

#
# 停止容器
#
"${COMPOSE[@]}" down
