---
title: "使用nginx代理vue项目静态文件"
date: 2021-05-07T03:10:06Z
description: "使用nginx代理vue项目静态文件"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/7BE310B6A34944D39F0CDCB2CBE72CE0?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "vue"
  - "nginx"
  - "docker"
tags:
  - "vue"
  - "nginx"
  - "docker"
---

#### nginx代理vue静态文件

- Dockerfile

```
FROM node:16-alpine AS builder

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

#RUN yarn config set proxy http://ip:port

#RUN yarn config set registry http://registry.npm.taobao.org

RUN npm config set proxy http://ip:port

RUN npm config set registry http://registry.npm.taobao.org

ADD . /usr/src/app

#RUN yarn

#RUN yarn run build

RUN npm install

RUN npm run build

FROM nginx:alpine

COPY --from=builder /usr/src/app/dist /usr/share/nginx/html

ENV HOST 0.0.0.0

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

>注意：在nginx:alpine里面的default.conf得加上try_files配置，否则通过nginx代理vue的static静态文件会返回空白页面，启动一个临时容器copy下default.conf下来改一下再重新build一下镜像，再用修改过的nginx镜像来运行vue项目即可。

- defualt.conf

```
...
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
	    try_files $uri $uri/ /index.html;
    }
...
```

- 修改nginx的Dockerfile

```
FROM nginx:alpine
ADD ./default.conf /etc/nginx/conf.d/default.conf
```
```
docker build -t gsol/nginx:alpine -f .
```

#### node直接运行vue项目文件

```
FROM node:alpine

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

RUN echo "host yourcompany.com" >> /etc/hosts

ADD . /usr/src/app

RUN yarn

RUN yarn run build

ENV NODE_ENV=production

ENV HOST 0.0.0.0

CMD [ "yarn", "start" ]
```
