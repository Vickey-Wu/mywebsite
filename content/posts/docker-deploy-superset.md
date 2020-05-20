---
title: "docker部署superset"
date: 2019-01-01T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/0D130F7FEE104F75B825F7AC0A209120?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "superset"
  - "docker"
---

### 一、使用自己的数据库
#### 1. 拉取项目

```
# 创建目录用于存放项目
mkdir -p /mnt/superset
cd /mnt/superset
git clone https://github.com/amancevice/superset.git
```

#### 2. 配置数据库等

> 这里默认你已创建了你自己的空数据库和具有读写该数据库权限的用户，到下面初始化时会自动在你的数据库创建表结构用于导入你的数据。如果没有可以使用项目自带的demo数据库

```
进入项目目录
cd /mnt/superset/superset
按照官网文档填写配置信息
```

[superset_config.py](https://superset.incubator.apache.org/installation.html#configuration)

```
ROW_LIMIT = 5000

SUPERSET_WEBSERVER_PORT = 8088

SECRET_KEY = 'set_your_own_key'

SQLALCHEMY_DATABASE_URI = 'mysql://user:pass@host:port/db'


# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []
# A CSRF token that expires in 1 year
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365

# Set this API key to enable Mapbox visualizations
MAPBOX_API_KEY = ''
```

#### 3. 启动容器

注意：
> 1.-v 挂载配置文件必须挂载到容器的/etc/superset/superset_config.py或者/home/superset/superset_config.py，因为容器里面的环境变量是这两个，挂载到其他路径初始化数据库会不生效。

> 2.SECRET_KEY必须与superset_config.py的设置一致

> 3.填写你自己数据库连接信息

```
docker run -d --name superset_name \
    --env SECRET_KEY="set_your_own_key" \
    --env SQLALCHEMY_DATABASE_URI="mysql://user:pass@host:port/db" \
    -p 8089:8088 \
    amancevice/superset
```

#### 4. 初始化容器

```
进入superset-init文件目录
cd /mnt/superset/superset/superset
初始化，如果用阿里云的rds的非首次使用不用初始化，否则数据会丢失
docker exec -it superset_name superset-init
输入你设置登录superset前端的admin相关信息
Username [admin]: admin
User first name [admin]: vickey
User last name [user]: vickey
password: mypassword
repeat passwd: mypassword
输入完毕开始初始化，等待完成即可
```

#### 5.前端访问

```
`http://ip:8088/`
```

### 二、使用项目demo数据库

```
启动容器（假设我们创建了/mnt/superset）
cd /mnt/superset/
git clone https://github.com/amancevice/superset.git
cd superset
docker-compose up -d
docker-compose exec superset demo
前端访问
http://ip:8088/
```

### 三、参考链接
- [项目教程链接](https://github.com/amancevice/superset/blob/master/README.md)
- [配置文件链接](https://superset.incubator.apache.org/installation.html#configuration)
- [他人教程链接](https://devhub.io/repos/amancevice-superset)
- [最新官网文档](https://github.com/apache/incubator-superset/blob/master/docs/installation.rst#user-content-start-with-docker)

使用源码安装有2个坑
> 1.docker-compose里面默认是开发环境安装，所以按照文档去做基本也会报npm error那个错，我们要先按照如下说明先修改环境为生产环境。`It is also possible to run Superset in non-development mode: in the docker-compose.yml file remove the volumes needed for development and change the variable SUPERSET_ENV to production.`

> 2.因为有墙的原因，dockerfile拉取依赖包安装nodejs时会超时而报错，所以我们得用香港或国外的服务器拉取依赖。

solution

```
# 翻墙下载依赖包nodejs_10.15.0-1nodesource1_amd64.deb
curl -sLO https://deb.nodesource.com/node_10.x/pool/main/n/nodejs/nodejs_10.15.0-1nodesource1_amd64.deb .
docker cp nodejs_10.15.0-1nodesource1_amd64.deb test-super:/var/cache/apt/archives/
```
