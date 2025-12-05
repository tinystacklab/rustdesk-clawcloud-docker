FROM debian:12

# 安装依赖：socat 用于端口转发，curl 和 ca-certificates 用于下载，bash 作为shell
RUN apt-get update && \
    apt-get install -y --no-install-recommends socat curl ca-certificates bash && \
    rm -rf /var/lib/apt/lists/*

# 创建工作目录并下载 RustDesk 服务器组件
RUN mkdir -p /opt/rustdesk && cd /opt/rustdesk && \
    curl -LO https://github.com/rustdesk/rustdesk-server/releases/latest/download/hbbs && \
    curl -LO https://github.com/rustdesk/rustdesk-server/releases/latest/download/hbbr && \
    chmod +x hbbs hbbr

# 创建数据目录（用于存储公钥等）
RUN mkdir -p /var/lib/rustdesk

# 复制启动脚本
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

# 只暴露 30000/tcp 端口
EXPOSE 30000/tcp

# 设置启动命令
CMD ["/opt/start.sh"]