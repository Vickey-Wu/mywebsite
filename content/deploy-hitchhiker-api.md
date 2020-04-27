---
title: "docker部署hitchhiker-api"
date: 2018-12-01T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/BB659B06E2944806A2CD7D375EBFD7AF?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "api"
tags:
  - "api"
  - "docker"
---

#### 一、 directory tree

```
hitchhiker
  hitchhiker
    docker-compose.yml
    hitchhiker-mysql.cnf
  nginx
    hitchhiker.conf
  sqldata(数据挂载目录)
    ...
```

#### 二、file content

```
docker-compose.yml
version: '2'
services:
hitchhiker:
  image: registry.cn-hangzhou.aliyuncs.com/brook/hitchhiker-cn:v0.14
  container_name: hitchhiker
  environment:
    - HITCHHIKER_DB_HOST=hitchhiker-mysql
    - HITCHHIKER_APP_HOST=http://ip:8080/
    #- HITCHHIKER_APP_HOST=http://ip:port/ # should change before deploying.
    # add environment variable
    - HITCHHIKER_MAIL_CUSTOM_TYPE=smtp
    - HITCHHIKER_MAIL_SMTP_HOST=smtp.exmail.qq.com
    - HITCHHIKER_MAIL_SMTP_PORT=465
    - HITCHHIKER_MAIL_SMTP_TLS=1
    - HITCHHIKER_MAIL_SMTP_USER=test@qq.com
    - HITCHHIKER_MAIL_SMTP_PASS=password
  # stresstest port:11010
  ports:
    - "11010:11010"
  links:
    - hitchhiker-mysql:hitchhiker-mysql
hitchhiker-mysql:
  image: mysql:5.7
  container_name: hitchhiker-mysql
  environment:
    - MYSQL_ROOT_PASSWORD=hitchhiker888
    - MYSQL_DATABASE=hitchhiker-prod
  ports:
    - "33060:3306"
  volumes:
    - ./hitchhiker-mysql.cnf:/etc/mysql/conf.d/hitchhiker.cnf
    - /mnt/hitchhiker/sqldata:/var/lib/mysql
hitchhiker-nginx:
  image: nginx:1.7.9
  container_name: hitchhiker-nginx
  ports:
    - "8080:80"
  volumes:
    - /mnt/hitchhiker/nginx/hitchhiker.conf:/etc/nginx/conf.d/default.conf
  links:
    - hitchhiker:hitchhiker
```

nginx hitchhiker.conf

```
server{
      listen 80;
      location / {
           #proxy_pass http://publicIp_or_containerIp:8080;
           proxy_pass http://hitchhiker:8080;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           allow x.x.x.0/24;
           deny all;
      }
}
```

hitchhiker-mysql

```
[mysqld]
collation-server=utf8_general_ci
init-connect='SET NAMES utf8'
character-set-server=utf8
max_allowed_packet=200M
```

#### 三、 deploy steps

1.找个目录创建“一、”步骤的目录树

2.将“二、”步骤的文件内容复制到指定文件并修改一些自定义参数

3.在docker-compose.yml文件所在目录下执行docker-compose up，可以看到日志输出，如果不想看可以执行docker-compose up -d

4.打开浏览器输入你的服务器ip:port映射的端口，我这里的是8080，第一次使用需要注册账号或点击注册框下面的try without password免登陆试玩就可以玩了
