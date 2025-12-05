#!/bin/bash
set -e  # 遇到错误立即退出，提高脚本可靠性

# 配置参数 - 调整为 Dockerfile 中实际的路径
PORT=30000
WORKDIR=/var/lib/rustdesk
PUBKEY_FILE="$WORKDIR/id_ed25519.pub"
HBBS_PATH="/opt/rustdesk/hbbs"  # 改为 Dockerfile 中实际的安装路径
HBBR_PATH="/opt/rustdesk/hbbr"  # 改为 Dockerfile 中实际的安装路径

# 1. 初始化环境
echo "[RustDesk Docker] 初始化环境..."
mkdir -p $WORKDIR

# 2. 安装依赖（socat）- Dockerfile 已安装，这里可以简化检查
echo "[RustDesk Docker] 检查 socat..."
if ! command -v socat >/dev/null 2>&1; then
    echo "[错误] socat 未安装，请检查 Dockerfile 配置"
    exit 1
fi

# 3. 验证 hbbs/hbbr 可执行性
echo "[RustDesk Docker] 验证 hbbs/hbbr 可执行性..."
if [ ! -x "$HBBS_PATH" ]; then
    echo "[错误] hbbs 不可执行：$HBBS_PATH"
    ls -la /opt/rustdesk/  # 调试信息：列出目录内容
    exit 1
fi

if [ ! -x "$HBBR_PATH" ]; then
    echo "[错误] hbbr 不可执行：$HBBR_PATH"
    ls -la /opt/rustdesk/  # 调试信息：列出目录内容
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
    # 调试信息：查看服务日志
    echo "[调试] hbbs 日志："
    cat $WORKDIR/hbbs.log 2>/dev/null || echo "  日志文件不存在"
    echo "[调试] hbbr 日志："
    cat $WORKDIR/hbbr.log 2>/dev/null || echo "  日志文件不存在"
fi

# 7. 保持容器运行（等待所有后台进程）
echo "[RustDesk Docker] 服务运行中，按 Ctrl+C 停止..."
wait $SOCAT_HBBS_PID $SOCAT_HBBR_PID $HBBS_PID $HBBR_PID