---
title: "redis基本用法"
date: 2019-07-20T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/AFBD8594B66F4270873718150F070860?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "redis"
tags:
  - "redis"
  - "docker"
---

### 前言

>reference: `https://www.tutorialspoint.com/redis/redis_quick_guide.htm`

>scrapy过滤重复链接使用到了redis，所以就先熟悉了下redis的基础。这篇笔记记录了redis的安装、配置、操作数据类型等

### 优势和劣势

#### redis优势 (remote dictionary server)

- Redis将其数据库完全保存在内存中，仅将磁盘用于持久性
- 每秒可以处理超过`10万次读写`操作
- Redis具有相对丰富的数据类型集
- 所有Redis操作都是原子操作
- 适用场景如缓存，消息队列（Redis本身支持发布/订阅）

#### redis劣势

- 也正因纯内存操作，受到物理内存限制，不能用作海量数据高性能读写，局限适用在较小数据场景

### 安装与配置

#### 安装 (ubuntu)

```
root@78a543194a68:/# apt-get update
root@78a543194a68:/# apt install redis-server       # 安装redis
root@78a543194a68:/# redis-server &                 # 后台启动
[1] 355
......
355:M 19 Jun 09:12:47.653 * Ready to accept connections

root@78a543194a68:/# redis-cli                      # redis默认未设置密码
127.0.0.1:6379> PING                                # 可用tab补全
PONG
root@78a543194a68:/# redis-cli -h host_or_ip -p port -a password      # 如有设置密码则需要提供密码登录
root@78a543194a68:/# redis-cli                       # 或进入后用`auth password`验证用户
127.0.0.1:6379> AUTH password
```
#### 配置

要更新配置，可以直接编辑redis.conf文件(**推荐**)，也可以通过CONFIG SET命令更新配置。

- 通过`redis.conf`修改配置(不同安装方式可能存放目录不同)

```
root@78a543194a68:/# cd /etc/redis/
root@78a543194a68:/etc/redis# ls
redis.conf
root@78a543194a68:/etc/redis# vim redis.conf        # 修改配置
```

>考虑更改或启用这几项，其他配置项保持默认基本满足需求。

```
bind 0.0.0.0                        # 为了能够远程连接redis，可以这样设置，最好设置成允许特定地址段
dbfilename dump-vickey.rdb          # 数据库文件名称，默认dump.rdb
dir /data                     # 数据库数据存放路径，可指定其他路径
requirepass self_defined_passwd     # 此redis的密码，默认未启用
# slaveof <masterip> <masterport>   # redis默认没有打开，当此redis作为其他redis的slave节点时，填上master redis的ip和port
# masterauth <master-password>      # 当slaveof打开且master redis设置了密码时需要填上
no-appendfsync-on-rewrite yes       # 如果您有延迟问题设为yes。否则no是最安全的选择。
```

- redis.conf已启用的配置项

```
root@78a543194a68:/etc/redis# grep -v "^$" redis.conf |grep -v "^#"
daemonize no
pidfile /var/run/redis.pid
port 6379
tcp-backlog 511
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
requirepass self_defined_passwd
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

- 通过`127.0.0.1:6379> CONFIG SET `，这种配置方式redis`重启后会失效`！

```
127.0.0.1:6379> CONFIG GET loglevel
1) "loglevel"
2) "notice"
127.0.0.1:6379> CONFIG SET loglevel "debug"
OK
127.0.0.1:6379> CONFIG GET loglevel
1) "loglevel"
2) "debug"
```
- **使用redis镜像**

>直接用redis的docker镜像的话，它没有留有配置文件在里面，要修改的话只能自己挂载一个配置文件进去。

>reference: `https://hub.docker.com/_/redis`

```
root@ubuntu:/home/vickey/scrapy_project/db# docker run -itd --name scrapy_redis -v /home/vickey/scrapy_project/db/redis.conf:/usr/local/etc/redis/redis.conf -p 8889:6379 redis redis-server /usr/local/etc/redis/redis.conf
fa2b076097e99deee696d6451e32a9457be86578a9eaea1558a8bf8ca6b5ed1f
root@ubuntu:/home/vickey/scrapy_project/db# docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED              STATUS              PORTS                               NAMES
fa2b076097e9        redis                     "docker-entrypoint.s…"   About a minute ago   Up About a minute   0.0.0.0:8889->6379/tcp              scrapy_redis
root@ubuntu:/home/vickey/scrapy_project/db# docker exec -it scrapy_redis /bin/bash
root@fa2b076097e9:/data# ls
dump-vickey.rdb
root@fa2b076097e9:/data# redis-cli 
127.0.0.1:6379> KEYS *
(error) NOAUTH Authentication required.
127.0.0.1:6379> AUTH 123123
OK
127.0.0.1:6379> KEYS *
(empty list or set)
```

## 操作redis数据类型

>如需查看所有命令请查看：`https://www.tutorialspoint.com/redis/redis_quick_guide.htm`

#### 概览

>Redis支持5种类型的数据。

- **strings**：redis字符串命令用于**管理**redis中的字符串类型**键的值**
- **hashes**：redis哈希类型是**字符串键**和**字符串值**之间的**映射**
- **lists**：redis列表只是按插入顺序排序（**后插入的排前面**）的**字符串列表**。
- **sets**：redis具有唯一字符串(**值不能重复**)的**无序集合**。
- **sorted sets**：redis的**有序集合**

#### 语法

```
127.0.0.1:6379> COMMAND KEY_NAME
```

#### strings例子

>redis字符串命令用于**管理**redis中的字符串类型**键的值**。

- 使用场景

1. 增删改查一个独立的属性，属性经常变动的场景，如点赞数，关注数

```
127.0.0.1:6379> SET name vickey         # 设置一个名为name，值为vickey的键
OK
127.0.0.1:6379> GET name                # 获取名为name的键的值，存在返回它的值vickey, 不存在则返回nil
"vickey"
127.0.0.1:6379> SET name wu             # 再次设置则相当于修改键name的值
OK
127.0.0.1:6379> GET name                # 键name的值vickey已被更改为wu
"wu"
127.0.0.1:6379> STRLEN name             # 获取键name的值wu的长度为2
(integer) 2
127.0.0.1:6379> SET name vickey
OK
127.0.0.1:6379> STRLEN name
(integer) 6


127.0.0.1:6379> APPEND name wu          # 向键name拼接一个值wu，返回值的长度8
(integer) 8
127.0.0.1:6379> GET name                # 新值为vickeywu
"vickeywu"
127.0.0.1:6379> STRLEN name
(integer) 8

127.0.0.1:6379> DEL name                # 删除键name，成功返回1
(integer) 1
127.0.0.1:6379> GET name                # 不存在键name， 则返回nil
(nil)
127.0.0.1:6379> EXISTS name             # 判断是否存在一个名为name的键，不存在返回0
(integer) 0
```

#### hashes例子

>redis哈希类型是**字符串键**和**字符串值**之间的**映射**

- 使用场景

1. 由多个属性构成一个属性的场景，如用户信息等

```
127.0.0.1:6379> HMSET hash_test name vickey age 18      # 设置一个名为hash_test表，值是包括名为name值为vickey的键，和名为age值为18的键，可以同时设置多个键
OK
127.0.0.1:6379> HGETALL hash_test                       # 获取哈希表所有键和值
1) "name"
2) "vickey"
3) "age"
4) "18"

127.0.0.1:6379> HLEN hash_test                          # 获取哈希表的长度
(integer) 2
127.0.0.1:6379> HKEYS hash_test                         # 哈希表包含的键
1) "name"
2) "age"
127.0.0.1:6379> HVALS hash_test                         # 哈希表包含的值
1) "vickey"
2) "18"

127.0.0.1:6379> HGET hash_test name                     # 获取哈希表hash_test的键name的值
"vickey"
127.0.0.1:6379> HGET hast_test vickey                   # vickey是键name的值，不是hash_test的键，所以返回nil
(nil)

127.0.0.1:6379> HEXISTS hash_test name                  # 判断哈希表hash_test是否存在键name
(integer) 1

127.0.0.1:6379> HDEL hash_test age                      # 删除表hash_test中的键name，删除成功返回1
(integer) 1
127.0.0.1:6379> HGETALL hash_test                       # 的确已经删除键name
1) "name"
2) "vickey"
```

#### lists例子

>redis列表只是按插入顺序排序（**后插入的排前面**）的**字符串列表**。

- 使用场景

1. 作为消息队列

```
127.0.0.1:6379> LPUSH list_test vickey                      # 向列表list_test插入一个值为vickey的字符串，成功返回列表长度
(integer) 1
127.0.0.1:6379> LRANGE list_test 0                          # lrange需要指定列表名list_test和列表下限和上限，缺失则报错。
(error) ERR wrong number of arguments for 'lrange' command
127.0.0.1:6379> LRANGE list_test 0 9                        # 获取列表list_test第1到第10个值，但只有一个值，所以只返回一个值
1) "vickey"


127.0.0.1:6379> LPUSH list_test wu
(integer) 2
127.0.0.1:6379> LLEN list_test                              # 查询列表list_test长度
(integer) 2


127.0.0.1:6379> LRANGE list_test 0 -1                       # 获取列表list_test所有值，可以看到后插入的wu排在了先插入的vickey之前
1) "wu"
2) "vickey"
127.0.0.1:6379> LINDEX list_test 0                          # 从索引也可以看到后插入的wu排在了第一位，使用了索引0
"wu"
127.0.0.1:6379> LINDEX list_test 1
"vickey"


127.0.0.1:6379> LPUSH list_test lastsecond lastone          # 同时向列表list_test插入lastsecond和lastone两个值，返回列表总长度4
(integer) 4
127.0.0.1:6379> LPUSH list_test lastone                     # 列表值可以重复插入
(integer) 5
127.0.0.1:6379> LPOP list_test                              # 删除并返回列表第一个值，也就是后插入的值先被删除
"lastone"
127.0.0.1:6379> LPOP list_test
"lastsecond"
127.0.0.1:6379> LPOP list_test
"wu"
127.0.0.1:6379> LPOP list_test
"vickey"
127.0.0.1:6379> LPOP list_test                              # 继续执行将继续删除倒数第二个值，直到全部删完返回nil
(nil)
```

#### sets例子

>redis集合是唯一字符串(**值不能重复**)的**无序集合**。

- 使用场景
1. 发现用户之间的交集属性，进行相关好友、话题推荐
2. 统计访问网站ip

```
127.0.0.1:6379> SADD set_test vickey        # 向集合set_test插入值vickey，插入成功返回插入的值数量
(integer) 1
127.0.0.1:6379> SADD set_test wu
(integer) 1
127.0.0.1:6379> SADD set_test age 18           # 向集合set_test同时插入值age，18，插入成功返回插入的值数量为2
(integer) 2

127.0.0.1:6379> SMEMBERS set_test           # 发现跟列表不同，集合是随机排列的
1) "wu"
2) "age"
3) "18"
4) "vickey"

127.0.0.1:6379> SADD set_test vickey        # 插入重复值vickey失败，返回0
(integer) 0
127.0.0.1:6379> SMEMBERS set_test           # 的确没有重复值vickey，并且执行插入操作后集合的排列顺序又变了
1) "age"
2) "18"
3) "vickey"
4) "wu"

127.0.0.1:6379> SCARD set_test              # 查询集合中包含元素总量
(integer) 4

127.0.0.1:6379> SPOP set_test               # 删除操作也是随机删除
"vickey"
```

#### sorted sets

>redis的**有序集合**

- 使用场景

1. 如计算用户得分等有权重区分的场景

```
127.0.0.1:6379> ZADD zset_test 0 vickey         # 向有序集合zset_test的索引0即第1个位置插入值vickey
(integer) 1
127.0.0.1:6379> ZADD zset_test 1 wu
(integer) 1
127.0.0.1:6379> ZADD zset_test 0 age 1 18       # 同时在第1和第2个索引位置插入age, 18两个值
(integer) 1
127.0.0.1:6379> ZRANGE zset_test 0 -1           # 获取有序集合zset_test的所有值
1) "age"
2) "18"
3) "vickey"
4) "wu"
127.0.0.1:6379> ZCARD zset_test                 # 获取有序集合zset_test的值的总数
(integer) 4
127.0.0.1:6379> ZRANK zset_test vickey          # 获取值vickey在有序集合zset_test中的索引，vickey在第3，所以返回索引为2
(integer) 2
127.0.0.1:6379> ZRANK zset_test wu              # 获取值wu在有序集合zset_test中的索引，wu在第4，所以返回索引为3
(integer) 3
```

#### 常用操作

- 认证密码

```
auth passwd
```

- 选择数据库

>选择数据库

```
select dbnumber
```
- 查询键类型

```
type keyname
```

## 结语

>这篇笔记熟悉了redis的安装、配置、操作数据类型等，篇幅有限，下一篇开始正题---scrapy过滤重复链接
