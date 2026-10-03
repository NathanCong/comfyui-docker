#
# 选择基础镜像
#
# ubuntu22.04：Ubuntu 22.04 系统
# 11.8.0：CUDA 11.8，用于 GPU 计算
# cudnn8：cuDNN 8，提供深度学习常用的 GPU 运算库
# devel：开发版本，包含编译 CUDA 程序所需的工具和头文件
#
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

#
# 声明构建参数（docker build）
#
# DEBIAN_FRONTEND=noninteractive  安装系统软件时避免弹出交互式配置界面
# COMFYUI_REPO                    ComfyUI 的 Git 仓库地址
# COMFYUI_REF                     要获取的 ComfyUI 分支、标签或提交，默认 master
# MULTIGPU_REPO                   MultiGPU 插件的 Git 仓库地址
# MULTIGPU_REF                    插件的版本引用，默认 main
# TORCH_VERSION                   PyTorch 版本
# TORCH_VISION_VERSION            PyTorch 视觉库版本
# TORCH_AUDIO_VERSION             PyTorch 音频库版本
#
ARG DEBIAN_FRONTEND=noninteractive
ARG COMFYUI_REPO=https://github.com/Comfy-Org/ComfyUI.git
ARG COMFYUI_REF=master
ARG MULTIGPU_REPO=https://github.com/pollockjj/ComfyUI-MultiGPU.git
ARG MULTIGPU_REF=main
ARG TORCH_VERSION=2.7.1
ARG TORCH_VISION_VERSION=0.22.1
ARG TORCH_AUDIO_VERSION=2.7.1

#
# 设置环境变量（docker）
#
# PIP_NO_CACHE_DIR=1         禁止 pip 保留下载缓存，减少镜像体积
# PYTHONDONTWRITEBYTECODE=1  避免 Python 写入 .pyc 字节码缓存文件
# PYTHONUNBUFFERED=1         让 Python 输出及时进入容器日志
# COMFYUI_PORT=8188          设置 ComfyUI 默认监听端口
# COMFYUI_CUDA_DEVICE=all    启动脚本会把它传给 --cuda-device
# COMFYUI_EXTRA_ARGS=""      预留额外启动参数，默认没有
#
ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    COMFYUI_PORT=8188 \
    COMFYUI_CUDA_DEVICE=all \
    COMFYUI_EXTRA_ARGS=""

#
# 配置系统环境（ubuntu）
#
# git              用于下载 ComfyUI 和插件源码
# ca-certificates  提供 HTTPS 证书验证所需的根证书
# curl             发起 HTTP 请求，后面用于健康检查
# python3          Python 解释器
# python3-dev      编译 Python 扩展所需的头文件等
# python3-pip      Python 包安装工具
# python3-venv     创建 Python 虚拟环境
# build-essential  GCC、G++、Make 等编译工具
# ffmpeg           音视频编解码和处理
# libgl1           OpenGL 运行库，一些图像处理依赖需要它
# libglib2.0-0     一些图像、多媒体库依赖的基础运行库
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates curl python3 python3-dev python3-pip python3-venv \
        build-essential ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv

#
# 设置环境变量（ubuntu）
#
ENV PATH=/opt/venv/bin:$PATH

#
# 设置工作目录
#
WORKDIR /opt

#
# 下载仓库代码
#
RUN git clone --filter=blob:none --no-checkout "${COMFYUI_REPO}" ComfyUI \
    && git -C ComfyUI fetch --depth 1 origin "${COMFYUI_REF}" \
    && git -C ComfyUI checkout --detach FETCH_HEAD \
    && git clone --filter=blob:none --no-checkout "${MULTIGPU_REPO}" ComfyUI/custom_nodes/ComfyUI-MultiGPU \
    && git -C ComfyUI/custom_nodes/ComfyUI-MultiGPU fetch --depth 1 origin "${MULTIGPU_REF}" \
    && git -C ComfyUI/custom_nodes/ComfyUI-MultiGPU checkout --detach FETCH_HEAD

#
# 设置工作目录
#
WORKDIR /opt/ComfyUI

#
# 安装运行依赖
#
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt \
    && pip install --upgrade --force-reinstall \
        "torch==${TORCH_VERSION}" \
        "torchvision==${TORCH_VISION_VERSION}" \
        "torchaudio==${TORCH_AUDIO_VERSION}" \
        --index-url https://download.pytorch.org/whl/cu118

#
# 生成启动脚本
#
RUN cat > /usr/local/bin/start-comfyui <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

cd /opt/ComfyUI

args=(
  main.py
  --listen 0.0.0.0
  --port "${COMFYUI_PORT:-8188}"
  --cuda-device "${COMFYUI_CUDA_DEVICE:-all}"
  --disable-pinned-memory
)

# Add optional flags such as --cpu-vae, --lowvram, or --preview-method auto.
if [[ -n "${COMFYUI_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${COMFYUI_EXTRA_ARGS} )
  args+=( "${extra[@]}" )
fi

exec python "${args[@]}"
EOF

#
# 启动前初始化
#
RUN chmod +x /usr/local/bin/start-comfyui \
    && mkdir -p /opt/ComfyUI/models /opt/ComfyUI/input /opt/ComfyUI/output /opt/ComfyUI/user

#
# 声明服务端口
#
EXPOSE 8188

#
# 配置健康检查
#
# --interval=30s      常规检查间隔为 30 秒
# --timeout=5s        单次检查最多等待 5 秒
# --start-period=60s  启动宽限期为 60 秒，期间的失败通常不计入失败次数
# --retries=3         连续失败 3 次后标记为 unhealthy
#
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:${COMFYUI_PORT}/system_stats || exit 1

#
# 指定容器启动入口
#
ENTRYPOINT ["/usr/local/bin/start-comfyui"]
