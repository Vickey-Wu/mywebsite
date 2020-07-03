---
title: "nginx配置多域名 docker"
date: 2020-06-19T03:10:06Z
description: "nginx配置多域名 docker"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/7EFD242EE9854D15AFE134779B8B7EC5?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
  - "nginx"
tags:
  - "docker"
  - "nginx"
  - "domain"
---

#### 目录结构

```
.
├── log
│   ├── access.log
├── nginx.conf
├── sslkey
│   ├── vickey-wu.com.key
│   └── vickey-wu.com.pem
├── start.sh
└── vhosts
    ├── test1.vickey-wu.com.conf
    └── test2.vickey-wu.com.conf
```

#### 文件详解

##### 1.启动脚本`start.sh`

```

NAME=nginx
TAG=nginx
#docker rm -f $NAME
#--cpus 限制cpu -m限制内存
docker run -d --name $NAME \
 --log-opt max-size=2g \
 --log-opt max-file=3 \
 -p 80:80 \
 -p 443:443 \
 --restart=always \
 --cpus 1 \
 -m 1G \
 -v /home/nginx/log/:/var/log/nginx/ \
 -v /home/nginx/nginx.conf:/etc/nginx/nginx.conf \
 -v /home/nginx/vhosts:/etc/nginx/vhosts \
 -v /home/nginx/sslkey/:/etc/nginx/sslkey/ \
$TAG
```

##### 2.nginx.conf

只需将域名配置文件包含进来即可，如`include /etc/nginx/vhosts/*.conf;`

```
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/vhosts/*.conf;
}
```

##### 3.域名配置文件

多个域名只需复制多份，将`server_name`改为新的域名，根目录`location / `跳转到该域名指向新的服务就行了`{proxy_pass  http://yourservicehost:port;}`
```
server {
  listen 80;

  server_name test1.vickey-wu.com;

  access_log  /var/log/nginx/test1_access.log;
  error_log   /var/log/nginx/test1_error.log;

  #80强制跳转到443
  return 301 https://test1.vickey-wu.com$request_uri;
  location / {
    proxy_pass  http://yourservicehost:port;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    client_max_body_size 100m;
  }

}

server {
  listen 443 ssl;
  
  server_name test1.vickey-wu.com;
  proxy_redirect off;
  
  ssl_certificate /etc/nginx/sslkey/vickey-wu.com.pem;
  ssl_certificate_key /etc/nginx/sslkey/vickey-wu.com.key;

  ssl_session_timeout 5m;
  ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
  #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_protocols TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";

  access_log  /var/log/nginx/test1_access.log;
  error_log   /var/log/nginx/test1_error.log;

  location / {
    proxy_pass  http://yourservicehost:port;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    client_max_body_size 100m;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

  }
}
```
