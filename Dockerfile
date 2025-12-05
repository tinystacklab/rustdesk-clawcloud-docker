FROM debian:12

RUN apt-get update && \
    apt-get install -y iptables curl ca-certificates bash && \
    apt-get clean

RUN mkdir -p /opt/rustdesk && \
    cd /opt/rustdesk && \
    curl -LO https://raw.githubusercontent.com/rustdesk/rustdesk-server/master/scripts/install.sh && \
    bash install.sh

RUN mkdir -p /var/lib/rustdesk

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

EXPOSE 30000/tcp

CMD ["/opt/start.sh"]
