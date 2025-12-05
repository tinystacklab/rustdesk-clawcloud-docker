#!/bin/bash
PORT=30000
WORKDIR=/var/lib/rustdesk
PUBKEY_FILE="$WORKDIR/id_ed25519.pub"

echo "[RustDesk Docker] 配置 TCP 端口转发（使用 socat + SO_REUSEPORT）..."

# 检查 socat 是否支持 reuseport 选项（不同版本可能有差异）
if socat -h 2>&1 | grep -q "reuseport"; then
    REUSE_OPT="reuseport"
else
    REUSE_OPT="reuseaddr"
    echo "[警告] socat 版本不支持 reuseport，将使用 reuseaddr（可能存在兼容性问题）"
fi

# 使用 socat + SO_REUSEPORT 将 30000 同时转发到 21116（hbbs）和 21117（hbbr）
# 操作系统会将新连接均衡分配给两个 socat 进程
socat TCP-LISTEN:$PORT,fork,$REUSE_OPT TCP:127.0.0.1:21116 &
SOCAT_PID1=$!

socat TCP-LISTEN:$PORT,fork,$REUSE_OPT TCP:127.0.0.1:21117 &
SOCAT_PID2=$!

echo "[RustDesk Docker] 30000/tcp 已映射至 21116/21117（TCP-only）"

echo "[RustDesk Docker] 启动 hbbs..."
/opt/rustdesk/hbbs -r 127.0.0.1:21117 --workdir $WORKDIR &
HBBS_PID=$!

echo "[RustDesk Docker] 启动 hbbr..."
/opt/rustdesk/hbbr --workdir $WORKDIR &
HBBR_PID=$!

# ======================================
# 等待 hbbs/hbbr 生成 SSH 公钥
# ======================================
echo "[RustDesk Docker] 等待 RustDesk 公钥生成..."
while [ ! -f "$PUBKEY_FILE" ]; do
    sleep 1
done

echo ""
echo "========================================"
echo " RustDesk 服务器公钥（id_ed25519.pub）"
echo "========================================"
cat "$PUBKEY_FILE"
echo "========================================"
echo ""

# 等待所有后台进程结束，确保容器持续运行
wait $SOCAT_PID1 $SOCAT_PID2 $HBBS_PID $HBBR_PID