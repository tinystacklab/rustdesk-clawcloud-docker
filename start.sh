#!/bin/bash
set -e  # 遇到错误立即退出，提高脚本可靠性

# 配置参数
PORT=30000
WORKDIR=/var/lib/rustdesk
PUBKEY_FILE="$WORKDIR/id_ed25519.pub"
HBBS_PATH="/app/hbbs"  # 使用官方rustdesk-server镜像默认路径，可根据实际调整
HBBR_PATH="/app/hbbr"  # 使用官方rustdesk-server镜像默认路径，可根据实际调整

# 1. 初始化环境
echo "[RustDesk Docker] 初始化环境..."
mkdir -p $WORKDIR

# 2. 安装依赖（socat）
echo "[RustDesk Docker] 检查并安装 socat..."
install_socat() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y --no-install-recommends socat && apt-get clean
    elif command -v yum >/dev/null 2>&1; then
        yum install -y socat && yum clean all
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache socat
    else
        echo "[错误] 不支持的包管理器，无法安装 socat"
        exit 1
    fi
}

if ! command -v socat >/dev/null 2>&1; then
    install_socat
fi

# 3. 验证 hbbs/hbbr 可执行性
echo "[RustDesk Docker] 验证 hbbs/hbbr 可执行性..."
if [ ! -x "$HBBS_PATH" ]; then
    echo "[错误] hbbs 不可执行：$HBBS_PATH"
    exit 1
fi

if [ ! -x "$HBBR_PATH" ]; then
    echo "[错误] hbbr 不可执行：$HBBR_PATH"
    exit 1
fi

# 4. 配置端口转发（使用 socat + reuseaddr，兼容更多环境）
echo "[RustDesk Docker] 配置 TCP 端口转发：30000 -> 21116/21117..."
# 监听 30000 并转发到 hbbs (21116)
socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:21116 &
SOCAT_HBBS_PID=$!

# 监听 30000 并转发到 hbbr (21117)
socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:21117 &
SOCAT_HBBR_PID=$!

echo "[RustDesk Docker] 端口转发已启动，PID: $SOCAT_HBBS_PID (hbbs), $SOCAT_HBBR_PID (hbbr)"

# 5. 启动 RustDesk 服务（TCP-only 模式）
echo "[RustDesk Docker] 启动 hbbr..."
$HBBR_PATH --workdir $WORKDIR &
HBBR_PID=$!

echo "[RustDesk Docker] 启动 hbbs (TCP-only)..."
# -r: 指定中继服务器
# --tcp-port: 指定 hbbs TCP 端口（默认21116）
# --udp-port 0: 禁用 UDP（TCP-only 模式）
$HBBS_PATH -r 127.0.0.1:21117 --tcp-port 21116 --udp-port 0 --workdir $WORKDIR &
HBBS_PID=$!

echo "[RustDesk Docker] 服务已启动，PID: $HBBS_PID (hbbs), $HBBR_PID (hbbr)"

# 6. 等待公钥生成
echo "[RustDesk Docker] 等待公钥生成..."
timeout=60
elapsed=0
while [ ! -f "$PUBKEY_FILE" ] && [ $elapsed -lt $timeout ]; do
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ -f "$PUBKEY_FILE" ]; then
    echo ""
    echo "========================================"
    echo " RustDesk 服务器公钥（id_ed25519.pub）"
    echo "========================================"
    cat "$PUBKEY_FILE"
    echo "========================================"
    echo ""
else
    echo "[警告] 公钥生成超时（${timeout}s），请检查服务日志"
fi

# 7. 保持容器运行（等待所有后台进程）
echo "[RustDesk Docker] 服务运行中，按 Ctrl+C 停止..."
wait $SOCAT_HBBS_PID $SOCAT_HBBR_PID $HBBS_PID $HBBR_PID