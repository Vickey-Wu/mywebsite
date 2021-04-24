---
title: "haproxy基础笔记"
date: 2021-02-22T03:10:06Z
description:  "haproxy基础笔记"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/812FC1B340754E73A6C9371F2E140BB4?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "haproxy"
tags:
  - "haproxy"
---

#### 简介

HAProxy实现了一种事件驱动、单一进程模型，支持10k/s并发连接数，HAProxy还支持Session的保持和Cookie的引导。

#### 原理

前端（frontend）区域可以根据HTTP请求的header信息来定义一些规则，然后将符合某规则的请求转发到相应后端（backend）进行处理。因此HAProxy可以实现动静分离（动静分离简单来说就是指将静态请求转发到对应的静态资源服务器，将动态请求转发到动态资源服务器）


#### HAProxy详解配置文件

- 配置文件：/etc/haproxy/haproxy.cfg主要由两部分组成：global 和 proxies 配置段。

1. global全局配置段 包含log，pidfile，maxconn，user，daemon
2. proxies：代理配置段 包含defaults：为frontend, backend, listen提供默认配置；fronted：前端，相当于nginx，server {}；backend：后端，相当于nginx， upstream {}；listen：同时拥有前端和后端，适用于一对一环境
3. frontend，backend中的配置除acl、bind、http-request、http-response、use_backend外，其余的均可以配置在default域中
4. listen域是frontend域和backend域的组合，frontend域和backend域中所有的配置都可以配置在listen域下

详细参考：`https://eclass.uoa.gr/modules/document/file.php/D245/haproxy.pdf`

```
global
 daemon
 log /dev/log local2
 option redispatch
 retries 3
 maxconn 1000
 user haproxy
 group haproxy

defaults
 log global
 option dontlognull
 timeout connect 500ms
 timeout client 30s
 timeout server 30s

listen http-proxy 192.168.1.201:80
 mode http
 option httpchk GET /test
 balance roundrobin
 timeout server 30s
 timeout client 30s
 server server-01 192.168.1.101:80 check inter 2s
 server server-02 192.168.1.102:80 check inter 2s
 server server-03 192.168.1.103:80 check inter 2s

frontend http-frontend
 bind 192.168.100.101:80
 bind 192.168.100.102:80
 default_backend http_backend
backend http-backend
 balance leastconn
 server server-01 192.168.1.101:81 check inter 2s
 server server-02 192.168.1.102:81 check inter 2s
 server server-03 192.168.1.103:81 check inter 2s

frontend horizon-proxy
 ...
 cookie SERVERID insert indirect nocache
 default_backend horizon-servers
backend horizon-servers
 ...
 server horizon-01 192.168.16.91:80 check inter 1s
cookie horizon-01
 server horizon-02 192.168.16.92:80 check inter 1s
cookie horizon-02

listen stats
 bind *:81
 mode http
 stats enable
 stats-uri /haproxy?stats
```
#### HAProxy常用功能

- 配置日志

```
vim /etc/resyslog.conf

$ModLoad imtcp
$InputTCPServerRun 514
local2.*      /var/log/haproxy.log
```
```
systemctl restart rsyslog
systemctl reload haproxy
```

-  backend负载均衡

```
backend alias
    balance     roundrobin      # source, uri, etc
    server      app1 127.0.0.1:8080 check
    server      app2 127.0.0.1:8081 check
```

- 设置session会话绑定

HAProxy依靠真实服务器发送给客户端的cookie信息进行会话保持。

```
backend alias
    cookie      node insert nocache
    balance     roundrobin      # source, uri, etc
    server      app1 127.0.0.1:8080 check cookie node1
    server      app2 127.0.0.1:8081 check cookie node2
```

- 配置服务状态
```
backend alias
    stats       enable
    stats       admin if TRUE
    balance     roundrobin      # source, uri, etc
    server      app1 127.0.0.1:8080 check
    server      app2 127.0.0.1:8081 check
```

- 动静分离

```
frontend
    ...
    use_backend static  if url_static or host_static
    use_backend dynamic if url_php
    default_backend dynamic

backend static
    balance     roundrobin
    server      app1 127.0.0.1:8080 check

backend dynamic
    balance     roundrobin      # source, uri, etc
    server      app1 127.0.0.1:8080 check
    server      app2 127.0.0.1:8081 check
```

#### HAProxy后端服务状态检测

HAProxy支持后端web服务器状态检查，当其代理的后端服务器出现故障时，Haproxy会自动将该故障服务器摘除，当故障的服务器恢复后，Haproxy还会自动的将该服务器自动加入进来提供服务。

- 基于端口检测

```
listen alias1
    bind *:90
    stats enable
    stats admin if TRUE

listen alias2
    bind *:80
    balance roundrobin
    server      app1 127.0.0.1:8080 check port 80 addr 192.xxx inter 3000 fail 3 rise 5
    server      app2 127.0.0.1:8081 check port 80 addr 192.xxx inter 3000 fail 3 rise 5
```

- 基于URI检测

```
listen alias1
    bind *:90
    stats enable
    stats admin if TRUE

listen alias2
    mode http
    bind *:80
    balance roundrobin
    option httpchk GET /index.html          #如果index打不开则认为后端服务异常
    server      app1 127.0.0.1:8080 check
    server      app2 127.0.0.1:8081 check port 80 addr 192.xxx inter 3000 fail 3 rise 5
```

#### 参考文章

>`https://cloud.tencent.com/developer/article/1644907`

>`https://eclass.uoa.gr/modules/document/file.php/D245/haproxy.pdf`
