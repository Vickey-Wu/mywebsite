---
title: "docker部署harbor"
date: 2020-05-19T03:10:06Z
description: "docker部署harbor"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/C140886C3DC04974BF3C9540BA55F905?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
  - "harbor"
tags:
  - "docker"
  - "harbor"
---

#### 下载安装包

>下载online安装包比较小会快点

```
wget -P /usr/src https://github.com/goharbor/harbor/releases/download/v2.0.0/harbor-online-installer-v2.0.0.tgz
tar -xvf /usr/src/harbor-online-installer-v2.0.0.tgz -C /home/ubuntu/harbor
```

#### 修改配置文件

>修改域名，密码，和证书目录等

```
root@vickey:/home# cd /home/ubuntu/harbor
root@vickey:/home/ubuntu/harbor# vim harbor.yml.tmpl

hostname: hub.vickey-wu.com
  certificate: /your/certificate/path
  private_key: /your/private/key/path
harbor_admin_password: yourpassword

root@vickey:/home/ubuntu/harbor# mv harbor.yml.tmpl harbor.yml
```

#### 安装harbor

>看到如下日志即表明成功启动

```
root@vickey:/home/ubuntu/harbor# ./install.sh 
...
[Step 4]: starting Harbor ...
Creating network "harbor_harbor" with the default driver
Creating harbor-log ... done
Creating redis         ... done
Creating harbor-db     ... done
Creating registry      ... done
Creating registryctl   ... done
Creating harbor-portal     ... done
Creating harbor-core   ... done
Creating harbor-jobservice ... done
Creating nginx             ... done
✔ ----Harbor has been installed and started successfully.----

root@vickey:/home/ubuntu/harbor# docker ps|grep harbor
3fe9e644e0c0        goharbor/nginx-photon:v2.0.0         "nginx -g 'daemon of…"   About a minute ago   Up About a minute (healthy)   0.0.0.0:8080->8080/tcp, 0.0.0.0:8443->8443/tcp   nginx
1d07ca52acc7        goharbor/harbor-jobservice:v2.0.0    "/harbor/entrypoint.…"   About a minute ago   Up About a minute (healthy)                                                    harbor-jobservice
683fa66946bb        goharbor/harbor-core:v2.0.0          "/harbor/entrypoint.…"   About a minute ago   Up About a minute (healthy)                                                    harbor-core
e37ded5634e1        goharbor/harbor-registryctl:v2.0.0   "/home/harbor/start.…"   About a minute ago   Up About a minute (healthy)                                                    registryctl
4cf87d203020        goharbor/harbor-portal:v2.0.0        "nginx -g 'daemon of…"   About a minute ago   Up About a minute (healthy)   8080/tcp                                         harbor-portal
175a630b3809        goharbor/harbor-db:v2.0.0            "/docker-entrypoint.…"   About a minute ago   Up About a minute (healthy)   5432/tcp                                         harbor-db
d548846ad8ba        goharbor/registry-photon:v2.0.0      "/home/harbor/entryp…"   About a minute ago   Up About a minute (healthy)   5000/tcp                                         registry
cae187199942        goharbor/redis-photon:v2.0.0         "redis-server /etc/r…"   About a minute ago   Up About a minute (healthy)   6379/tcp                                         redis
385ba58e5e6e        goharbor/harbor-log:v2.0.0           "/bin/sh -c /usr/loc…"   About a minute ago   Up About a minute (healthy)   127.0.0.1:1514->10514/tcp                        harbor-log
```


#### 管理界面

>访问`https://hub.vickey-wu.com/`

![harbor2.0.0](https://note.youdao.com/yws/api/personal/file/B0F7096E2A6645CDA58195E22D7B0D49?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a)

>linux 登录仓库，如果你`nginx`不是用`443`端口会遇到`404`或`connection refused`的报错

```
root@vickey:/home/ubuntu/harbor# docker login -u admin hub.vickey-wu.com

Error response from daemon: login attempt to http://hub.vickey-wu.com/v2/ failed with status: 404 Not Found

Error response from daemon: Get https://hub.vickey-wu.com/v2/: dial tcp xxxxx:443: connect: connection refused

```

#### 创建删除镜像

>要先在管理界面创建项目`os`，`docker login`后就可以push、pull镜像到harbor了。

```
root@vickey:/home/ubuntu/harbor# docker tag goharbor/redis-photon:v2.0.0 hub.vickey-wu.com/os/os:v2.0.0
root@vickey:/home/ubuntu/harbor# docker  push hub.vickey-wu.com/os/os:v2.0.0
The push refers to repository [hub.vickey-wu.com/os/os]
12042912d563: Pushed 
87063a362784: Pushed 
3e72063a3c12: Pushed 
da380ff7675f: Pushed 
dbaf2c918102: Pushed 
v2.0.0: digest: sha256:3fa921ef8b17dcf543ced2d101029b1ada1128ee67ee7306a60e9688abe2429d size: 1366
root@vickey:/home/ubuntu# docker pull hub.vickey-wu.com/os/os:v2.0.0
Digest: sha256:3fa921ef8b17dcf543ced2d101029b1ada1128ee67ee7306a60e9688abe2429d
Status: Image is up to date for hub.vickey-wu.com/os/os:v2.0.0
hub.vickey-wu.com/os/os:v2.0.0
```

>可以看到已经上传到harbor仓库了

![](https://note.youdao.com/yws/api/personal/file/39A0D2A22D8146DB9F6E23552A72A295?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a)
#### 参考文章

>`https://goharbor.io/docs/2.0.0/install-config/download-installer/`

>`https://www.cnblogs.com/yinzhengjie/p/12233594.html`
