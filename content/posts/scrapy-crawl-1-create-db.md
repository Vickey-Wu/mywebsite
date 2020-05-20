---
title: "scrapy电影天堂实战---创建数据库"
date: 2019-07-10T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/866A54E79B2147C68C479092510C65CB?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "scrapy"
  - "mysql"
tags:
  - "scrapy"
  - "mysql"
  - "docker"
---

### 创建数据库

>首先我们需要创建数据库和表等来存储数据

#### 创建mysql.cnf配置文件

```
oot@ubuntu:/mnt/test_scrapy# cat mysql.cnf 
[mysql]
default-character-set = utf8mb4
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

#### 创建mysql库

```
root@ubuntu:/home/vickey/test_scrapy# docker run -itd --name scrapy_mysql -p 8886:3306 -e MYSQL_ROOT_PASSWORD=123456 -v /home/vickey/test_scrapy/mysql.cnf:/etc/mysql/conf.d/mysql.cnf mysql:latest
d8afb121afc65f9b4211d33885e73153c63eeb168122fe6d27f536d9bb27f0fe
root@ubuntu:/home/vickey/test_scrapy# docker exec -it scrapy_mysql /bin/bash
root@101bcf2ffb2d:/# mysql -uroot -p123456
mysql> show variables like '%charact%';
+--------------------------+--------------------------------+
| Variable_name            | Value                          |
+--------------------------+--------------------------------+
| character_set_client     | utf8mb4                        |
| character_set_connection | utf8mb4                        |
| character_set_database   | utf8mb4                        |
| character_set_filesystem | binary                         |
| character_set_results    | utf8mb4                        |
| character_set_server     | utf8mb4                        |
| character_set_system     | utf8                           |
| character_sets_dir       | /usr/share/mysql-8.0/charsets/ |
+--------------------------+--------------------------------+
8 rows in set (0.00 sec)

mysql> create database `movie_heaven_bar`;
Query OK, 1 row affected (0.00 sec)

mysql> use movie_heaven_bar;
Database changed
mysql> show create database movie_heaven_bar;
+------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| Database         | Create Database                                                                                                                            |
+------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
| movie_heaven_bar | CREATE DATABASE `movie_heaven_bar` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */ |
+------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
1 row in set (0.00 sec)
```

#### 创建表

```
mysql> create table newest_movie(id int not null auto_increment, movie_link varchar(100), movie_name varchar(100), movie_director varchar(100), movie_actors varchar(1500), movie_publish_date varchar(50), movie_score varchar(100), movie_download_link varchar(100), movie_hash varchar(100), primary key (`id`));
Query OK, 0 rows affected (0.02 sec)
```

#### [创建用户并授权](https://blog.csdn.net/weixin_38091140/article/details/82983229)

>`https://blog.csdn.net/weixin_38091140/article/details/82983229`

本例mysql是mysql8，授权方法为：`grant all privileges on movie_heaven_bar.* to 'movie'@'%' with grant option;`，mysql8以下的版本授权方法为：`grant all privileges on movie_heaven_bar.* to 'movie'@'%' identified by 'password';`

```
mysql> create user 'movie'@'%' identified by '123123';      # 已有用户则用alter user 'movie'@'%' identified by '123123';
Query OK, 0 rows affected (0.01 sec)
mysql> show grants for 'movie'@'%';
+-----------------------------------+
| Grants for movie@%                |
+-----------------------------------+
| GRANT USAGE ON *.* TO `movie`@`%` |
+-----------------------------------+
1 row in set (0.00 sec)
mysql> grant all privileges on movie_heaven_bar.* to 'movie'@'%' with grant option;
mysql> ALTER USER 'movie'@'%' IDENTIFIED WITH mysql_native_password BY '123123';      # 不改会报错：OperationalError: (2059, "Authentication plugin 'caching_sha2_password' cannot be loaded
Query OK, 0 rows affected, 1 warning (0.01 sec)
mysql> flush privileges;
Query OK, 0 rows affected (0.01 sec)

mysql> show grants for 'movie'@'%';
+-------------------------------------------------------------------------------+
| Grants for movie@%                                                            |
+-------------------------------------------------------------------------------+
| GRANT USAGE ON *.* TO `movie`@`%`                                             |
| GRANT ALL PRIVILEGES ON `movie_heaven_bar`.* TO `movie`@`%` WITH GRANT OPTION |
+-------------------------------------------------------------------------------+
2 rows in set (0.00 sec)
```
#### 结语

>很好，数据库创建完成，下一篇就是爬数据了，先来个图看看爬到数据效果。

![](https://note.youdao.com/yws/api/personal/file/E7546A924D9343ADB4C596A3ED72D6ED?method=download&shareKey=ace32e564664d77ee9de1228a8e8f9d2)
