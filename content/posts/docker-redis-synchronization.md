---
title: "docker配置redis主从同步"
date: 2020-05-06T03:10:06Z
description: "docker配置redis主从同步"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/C6F2C7BED410466290E090E8B018D223?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "docker"
  - "redis"
---

#### 一、文件概览

```
root@vickey:/home/ubuntu/redis-cluster# tree -l
.
├── redis-master.conf
├── redis-slave.conf
├── start-master.sh
└── start-slave.sh

0 directories, 4 files

```
##### 1. redis-master.conf和redis-slave.conf

>以下是master.conf配置，redis-slave.conf比redis-master.conf只是要多加一行配置`slaveof <masterip> <masterport>`，如果redis开启了密码则需要再加一行`masterauth <yourmasterpasswd>`。

```
daemonize no
pidfile /var/run/redis.pid
port 6379
tcp-backlog 511
#bind 127.0.0.1
#bind 192.168.0.1
bind 0.0.0.0
timeout 0
tcp-keepalive 0
loglevel notice
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump-vickey.rdb
dir /data
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slave-priority 100
requirepass yourpasswd
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
```

##### 2. master和slave启动脚本

>master和slave启动脚本，将`ROLE`, `PORT`等变量改下即可

```
ROLE=master
NAME=redis-${ROLE}
PORT=3338
CONFIG_PATH=/home/ubuntu/redis-cluster
# docker rm -f ${NAME}
docker run -itd --name ${NAME} \
 -v ${CONFIG_PATH}/redis-${ROLE}.conf:/usr/local/etc/redis/redis.conf \
 -p ${PORT}:6379 \
 redis redis-server /usr/local/etc/redis/redis.conf
```

#### 二、启动主从数据库

```
root@vickey:/home/ubuntu/redis-cluster# sh start-master.sh 
58cfedd1809ed7aed6c09b20767649c305f23f140510178858e6be98f451302a
root@vickey:/home/ubuntu/redis-cluster# sh start-slave.sh 
e382231e9e18695644064105459b3a510b3dba13ce16a6e37ee496db5ab256a9
root@vickey:/home/ubuntu/redis-cluster# docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED              STATUS              PORTS                                      NAMES
e382231e9e18        redis                     "docker-entrypoint.s…"   2 seconds ago        Up 1 second         0.0.0.0:3339->6379/tcp                     redis-slave
58cfedd1809e        redis                     "docker-entrypoint.s…"   About a minute ago   Up About a minute   0.0.0.0:3338->6379/tcp                     redis-master
```

此时我们查看redis-slave和redis-master的日志就可以看到已经开启了同步

1. redis-slave

```
root@vickey:/home/ubuntu/redis-cluster# docker logs -f --tail 50 redis-slave
......
1:S 06 May 2020 07:03:47.888 * Connecting to MASTER masterip:masterport
1:S 06 May 2020 07:03:47.889 * MASTER <-> REPLICA sync started
1:S 06 May 2020 07:03:47.889 * Non blocking connect for SYNC fired the event.
1:S 06 May 2020 07:03:47.890 * Master replied to PING, replication can continue...
1:S 06 May 2020 07:03:47.894 * Partial resynchronization not possible (no cached master)
1:S 06 May 2020 07:03:47.896 * Full resync from master: cd285decbbf4ade24ab913767dc9b39217eae11b:0
1:S 06 May 2020 07:03:47.906 * MASTER <-> REPLICA sync: receiving 193 bytes from master
1:S 06 May 2020 07:03:47.906 * MASTER <-> REPLICA sync: Flushing old data
1:S 06 May 2020 07:03:47.906 * MASTER <-> REPLICA sync: Loading DB in memory
1:S 06 May 2020 07:03:47.907 * MASTER <-> REPLICA sync: Finished with success
```

2. redis-master

```
root@vickey:/home/ubuntu/redis-cluster# docker logs -f --tail 50 redis-master
......
1:M 06 May 2020 07:03:47.895 * Replica masterip:6379 asks for synchronization
1:M 06 May 2020 07:03:47.895 * Full resync requested by replica masterip:6379
1:M 06 May 2020 07:03:47.895 * Starting BGSAVE for SYNC with target: disk
1:M 06 May 2020 07:03:47.895 * Background saving started by pid 22
22:C 06 May 2020 07:03:47.902 * DB saved on disk
22:C 06 May 2020 07:03:47.902 * RDB: 0 MB of memory used by copy-on-write
1:M 06 May 2020 07:03:47.905 * Background saving terminated with success
1:M 06 May 2020 07:03:47.906 * Synchronization with replica masterip:6379 succeeded
```

#### 三、验证同步

1. 在redis-slave查询不存在的key是nil的

```
root@vickey:/home/ubuntu/mywebsite# docker exec -it redis-slave /bin/bash
root@e382231e9e18:/data# redis-cli 
127.0.0.1:6379> auth yourpasswd
OK
127.0.0.1:6379> KEYS *
(empty list or set)
127.0.0.1:6379> GET name
(nil)
```

2. 进入redis-master新建key

```
root@vickey:/home/ubuntu/redis-cluster# docker exec -it redis-master /bin/bash
root@58cfedd1809e:/data# redis-cli 
127.0.0.1:6379> auth yourpasswd
OK
127.0.0.1:6379> KEYS *
(empty list or set)
127.0.0.1:6379> set name vickey
OK
127.0.0.1:6379> GET name
"vickey"
127.0.0.1:6379> 
```

3. 再次验证redis-slave就已经包含新建的key了

```
127.0.0.1:6379> GET name
"vickey"
```
