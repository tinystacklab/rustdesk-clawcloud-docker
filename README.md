# rustdesk-clawcloud-docker

RustDesk 服务端（HBBS/HBBR）单 TCP 端口版本  
外部只需暴露 `30000/tcp`

## 运行方式

```bash
docker run -d \
  --cap-add=NET_ADMIN \
  -p 30000:30000/tcp \
  ghcr.io/<yourname>/rustdesk-clawcloud-docker:latest
```

## 客户端设置

ID服务器：`IP:30000`  
中继服务器：`IP:30000`

即可正常使用（TCP-only 模式）。
