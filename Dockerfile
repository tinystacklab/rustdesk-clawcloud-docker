FROM debian:12

RUN apt-get update && \
    apt-get install -y iptables curl ca-certificates bash && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/rustdesk && cd /opt/rustdesk && \
    curl -LO https://github.com/rustdesk/rustdesk-server/releases/latest/download/hbbs && \
    curl -LO https://github.com/rustdesk/rustdesk-server/releases/latest/download/hbbr && \
    chmod +x hbbs hbbr

RUN mkdir -p /var/lib/rustdesk

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

EXPOSE 30000/tcp

CMD ["/opt/start.sh"]
