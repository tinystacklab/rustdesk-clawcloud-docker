#!/bin/bash
PORT=30000
WORKDIR=/var/lib/rustdesk
PUBKEY_FILE="$WORKDIR/id_ed25519.pub"

echo "[RustDesk Docker] 配置 TCP 端口重定向..."
iptables -t nat -F PREROUTING

iptables -t nat -A PREROUTING -p tcp --dport $PORT -j REDIRECT --to-ports 21116
iptables -t nat -A PREROUTING -p tcp --dport $PORT -j REDIRECT --to-ports 21117

echo "[RustDesk Docker] 30000/tcp 已映射至 21116/21117"

echo "[RustDesk Docker] 启动 hbbs..."
/opt/rustdesk/hbbs -r 127.0.0.1:21117 --workdir $WORKDIR &

echo "[RustDesk Docker] 启动 hbbr..."
/opt/rustdesk/hbbr --workdir $WORKDIR &

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

sleep infinity
