---
title: "dockerfile基础知识"
date: 2018-11-18T03:10:06Z
description: "dockefile basic"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/2204C912C119440F9E00156176B01612?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "docker"
  - "dockerfile"
---

#### dockerfile basic cmd

![dockerfile cmd](https://note.youdao.com/yws/api/personal/file/DC3C4D935C404D82A1A0B1D57634297B?method=download&shareKey=f0a59eb8e8d8809b631be8440ed87111)

- FROM:基于哪个镜像实现
- EXPOSE:容器内应用可以使用的端口
- ENV:容器内环境变量
- RUN:执行安装依赖等命令
- ADD:添加宿主机文件到容器里，会自动解压文件到容器
- COPY:添加宿主机文件到容器里，不会自动解压
- VOLUME:指定挂载目录，docker run -v可以挂载宿主机文件到容器里
- WORKDIR:容器启动后，docker exec -i进入容器的默认目录
- CMD:容器启动命令，如果docker run后面有启动命令会覆盖CMD的命令
- ENTRYPOINT:与CMD相同，容器启动命令，但不会被覆盖。
           默认情况下，Docker 会供一个隐含的 ENTRYPOINT，即：/bin/sh -c "bash cmd"。
           它和 CMD 都是 Docker 容器进程启动所必需的参数，完整执行格式是：“ENTRYPOINT CMD”。

#### [dockerfile 单阶段构建](https://github.com/docker-library/docs)

- nginx dockerfile

```
FROM nginx
# WORKDIR 创建容器后默认进入此目录
WORKDIR /code
# 优先使用copy
COPY ./test.json /app
# ADD当前目录文件到容器的/code目录
ADD . /code
# [add和copy比较](https://www.qikqiak.com/k8s-book/docs/13.Dockerfile%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.html)
EXPOS 8000
#env 通过docker run -e VERSION="10.0.1"即可修改用dockerfile构建的容器中version的版本号
ENV VERSION 9.3.4
RUN buildDeps='gcc libc6-dev make' \
    && apt-get update \
    && apt-get install $buildDeps \
    && wget -O redis.tar.gz "http://download/redis.tar.gz" \
    && tar -zxvf redis.tar.gz -C /usr/src/redis \
    && make -C /usr/src/redis \
    && make -C /usr/src/redis install \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/redis \
    && rm redis.tar.gz \
    && apt-get purge -y --auto-remove $buildDeps
    && rm -rf /var/lib/apt/lists/*
    # delete apt-get update cache can decrease images size
# 执行`python test.py`命令
CMD ["python", "test.py"]
```

- other

```
# scratch虚拟的镜像，只有linux最基本命令
FROM scratch
# RUN commands执行shell命令
# 把dockerfile所在目录下的test.json复制到容器的/app目录下，COPY不能用绝对路径，如test.json 在/tmp/test.json下，写错`COPY /tmp/test.json /app`会报错
COPY ./test.json /app
```

- build dockerfile

```
docker build -t nginx:v1 .
docker build -f ./dockerfile -t nginx:v1 ./
```

- save and load image

```
docker save -o nginx.tar nginx:v1
docker load -i nginx.tar
```

- `$pwd=${pwd}!=$(pwd)`

#### dockerfile other

```
curl https://raw.githubusercontent.com/${SUPERSET_REPO}/${SUPERSET_VERSION}/requirements.txt -o requirements.txt && \
# disable cache, -r pip instasll requirements.txt list pkg
pip install --no-cache-dir -r requirements.txt && \
rm requirements.txt
# healthcheck
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8088/health"]
# volume array or just string
VOLUME /home/superset /etc/superset /var/lib/superset
VOLUME ["/home/superset", "/etc/superset", "/var/lib/superset"]
```

#### dockerfile多阶段build

```
FROM golang:latest AS build-env
WORKDIR /go/src/app
ADD . /go/src/app
RUN go get -u -v github.com/kardianos/govendor \
    && govendor sync \
    && GOOS=linux GOARCH=386 go build -v -o /go/src/app/app-server
    
    
FROM scrath
COPY --from=build-nev /go/src/app/app-server .
EXPOSE 8080
CMD ["./app-server"]
```

>COPY --from=build-nev /go/src/app/app-server .

>从第一层构建生成的文件/go/src/app/app-server复制到第二层
