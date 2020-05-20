---
title: "docker-compose部署skywalking"
date: 2020-05-08T03:10:06Z
description: "docker-compose部署skywalking"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/A4805FD3D4FC45C28FFFC30E95BF4C1A?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker-compose"
tags:
  - "docker-compose"
  - "skywalking"
---

#### 一、编写docker-compose.yml

```
root@vickey:/home/ubuntu/skywalking# cat docker-compose.yml
version: '3.3'
services:
  elasticsearch:
    image: elasticsearch:7.4.2
    container_name: elasticsearch
    restart: always
    ports:
      - 9200:9200
    environment:
      discovery.type: single-node
    ulimits:
      memlock:
        soft: -1
        hard: -1
  oap:
    image: apache/skywalking-oap-server:7.0.0-es7
    container_name: oap
    depends_on:
      - elasticsearch
    links:
      - elasticsearch
    restart: always
    ports:
      - 11800:11800
      - 12800:12800
    environment:
      SW_STORAGE: elasticsearch7
      SW_STORAGE_ES_CLUSTER_NODES: elasticsearch:9200
  ui:
    image: apache/skywalking-ui
    container_name: ui
    depends_on:
      - oap
    links:
      - oap
    restart: always
    ports:
      - 8080:8080
    environment:
      SW_OAP_ADDRESS: oap:12800
```

#### 二、启动服务

看到这个日志就说明服务已经都起来了，访问hostip:8080即可

```
root@vickey:/home/ubuntu/skywalking# docker-compose up
Creating network "skywalking_default" with the default driver
Creating elasticsearch ... done
Creating oap           ... done
Creating ui            ... done
Attaching to elasticsearch, oap, ui
...             #此处省略一万字
oap              | 2020-05-08 03:26:15,042 - org.apache.skywalking.oap.server.library.server.jetty.JettyServer -92769 [main] INFO  [] - start server, host: 0.0.0.0, port: 12800
oap              | 2020-05-08 03:26:15,049 - org.eclipse.jetty.server.Server -92776 [main] INFO  [] - jetty-9.4.2.v20170220
oap              | 2020-05-08 03:26:15,148 - org.eclipse.jetty.server.handler.ContextHandler -92875 [main] INFO  [] - Started o.e.j.s.ServletContextHandler@7f2ca6f8{/,null,AVAILABLE}
oap              | 2020-05-08 03:26:15,174 - org.eclipse.jetty.server.AbstractConnector -92901 [main] INFO  [] - Started ServerConnector@177ddd24{HTTP/1.1,[http/1.1]}{0.0.0.0:12800}
oap              | 2020-05-08 03:26:15,174 - org.eclipse.jetty.server.Server -92901 [main] INFO  [] - Started @93091ms
oap              | 2020-05-08 03:26:15,176 - org.apache.skywalking.oap.server.core.storage.PersistenceTimer -92903 [main] INFO  [] - persistence timer start
oap              | 2020-05-08 03:26:15,189 - org.apache.skywalking.oap.server.core.cache.CacheUpdateTimer -92916 [main] INFO  [] - Cache updateServiceInventory timer start
```

#### 三、参考文档

`https://help.aliyun.com/document_detail/161783.html`
