---
title: "docker配置mysql主从同步"
date: 2020-04-30T03:10:06Z
description: "docker配置mysql主从同步"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/CC82F34E4CAB458F913FD79C5ED2FDA1?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "docker"
  - "mysql"
---

#### 一、文件概览

```
root@vickey:/home/ubuntu/mysql-cluster# tree -l
.
├── master
│   ├── data
│   ├── my-master.cnf
│   └── start.sh
└── slave
    ├── data
    ├── my-slave.cnf
    └── start.sh

4 directories, 4 files
```
##### 1. my-master.cnf和my-slave.cnf

>my-master.cnf和my-slave.cnf只是server-id不一样，也必须要不一样。配置文件中一定要开启log-bin相关配置，默认是不开启的，主从复制就是利用log-bin实现的

```
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
secure-file-priv= NULL
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
log-bin         = mysql-bin
log-bin-index   = mysql-bin.index
binlog_format   = mixed
server-id       = 1
sync-binlog     = 1
character-set-server = utf8

# Custom config should go here
!includedir /etc/mysql/conf.d/
```

##### 2. master和slave启动脚本start.sh

>master和slave启动脚本，将`ROLE`, `PORT`等变量改下即可

```
ROLE=master
PORT=3336
MYSQL_NAME=mysql-${ROLE}
PASSWD=passwd123
# docker rm -f ${MYSQL_NAME}
CONFIG_PATH=/home/ubuntu/mysql-cluster/${ROLE}
docker run -itd --name ${MYSQL_NAME} \
 -p ${PORT}:3306 \
 -e MYSQL_ROOT_PASSWORD=${PASSWD} \
 -v ${CONFIG_PATH}/my-${ROLE}.cnf:/etc/mysql/my.cnf \
 -v ${CONFIG_PATH}/data:/var/lib/mysql \
 mysql:5.7
```

#### 二、启动主从数据库

```
root@vickey:/home/ubuntu/mysql-cluster# sh master/start.sh 
Error: No such container: mysql-master
0e66ddf8f7b4937f21ed393a83c155af55bacd2ddc7ebe0d3e6bd9286945b06f
root@vickey:/home/ubuntu/mysql-cluster# sh slave/start.sh 
Error: No such container: mysql-slave
8537703a6a9dac07f7fa4bf993664572e51a52679b9bacbcc2eb6803dc703114

root@vickey:/home/ubuntu/mysql-cluster# docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED             STATUS              PORTS                                      NAMES
8537703a6a9d        mysql:5.7                 "docker-entrypoint.s…"   4 seconds ago       Up 3 seconds        33060/tcp, 0.0.0.0:3337->3306/tcp          mysql-slave
0e66ddf8f7b4        mysql:5.7                 "docker-entrypoint.s…"   20 seconds ago      Up 19 seconds       33060/tcp, 0.0.0.0:3336->3306/tcp          mysql-master
```

#### 三、主数据库操作

##### 1. 创建专用用户

```
root@vickey:/home/ubuntu/mysql-cluster# docker exec -it mysql-master /bin/bash
root@0e66ddf8f7b4:/# mysql -u root -p
Enter password: 
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
root@0e66ddf8f7b4:/# mysql -u root -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 3
Server version: 5.7.29-log MySQL Community Server (GPL)

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> create user 'slave-read'@'%' identified by 'passwd123';
Query OK, 0 rows affected (0.01 sec)

mysql> grant replication slave, replication client on *.* to 'slave-read'@'%' identified by 'passwd123';
Query OK, 0 rows affected, 1 warning (0.00 sec)
```

##### 2. 设置读锁并获取主数据库binlog当前位置

```
mysql> flush tables with read lock;
Query OK, 0 rows affected (0.00 sec)

mysql> show master status;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000003 |      714 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)

mysql> exit
Bye
```

##### 3. 备份主库所有库并解除读锁
```
root@0e66ddf8f7b4:/# mysqldump -uroot -p --all-databases -e --single-transaction --flush-logs --max_allowed_packet=1048576 --net_buffer_length=16384 > /home/all_db.sql
Enter password: 
root@0e66ddf8f7b4:/# ls home/
all_db.sql
root@0e66ddf8f7b4:/# mysql -u root -p
mysql> unlock tables;
Query OK, 0 rows affected (0.00 sec)
mysql> exit
Bye
root@0e66ddf8f7b4:/# exit
exit
root@vickey:/home/ubuntu/mysql-cluster# 

```

#### 四、从数据库容器操作

##### 1. 将主数据库备份数据导入到从数据库

```
root@vickey:/home/ubuntu/mysql-cluster# docker cp mysql-master:/home/all_db.sql slave/
root@vickey:/home/ubuntu/mysql-cluster# docker cp slave/all_db.sql mysql-slave:/home
root@vickey:/home/ubuntu/mysql-cluster# docker exec -it mysql-slave /bin/bash
root@8537703a6a9d:/# ls /home/
all_db.sql
root@8537703a6a9d:/# mysql -uroot -p </home/all_db.sql 
Enter password: 
root@8537703a6a9d:/# 
```

##### 2. 在从数据库同步主数据库的binlog位置

>注意：`master_log_file`和`master_log_pos`要根据你在主数据库`show master status;`获得的数据来改，不一定跟我的一样。还有yourip记得改为你自己的ip

```
root@8537703a6a9d:/# mysql -uroot -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 5
Server version: 5.7.29-log MySQL Community Server (GPL)

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> change master to master_host='yourip', master_user='slave-read', master_password='passwd123', master_port=3336, master_log_file='mysql-bin.000003', master_log_pos=714;
Query OK, 0 rows affected, 2 warnings (0.08 sec)

```

##### 3. 启动主从复制

>`Slave_IO_Running: Yes`和`Slave_SQL_Running: Yes`即表明主从同步成功启动。

```
mysql> start slave;
Query OK, 0 rows affected (0.01 sec)

mysql> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 111.229.39.228
                  Master_User: slave-read
                  Master_Port: 3336
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000004
          Read_Master_Log_Pos: 154
               Relay_Log_File: 8537703a6a9d-relay-bin.000004
                Relay_Log_Pos: 367
        Relay_Master_Log_File: mysql-bin.000004
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 154
              Relay_Log_Space: 628
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File: 
           Master_SSL_CA_Path: 
              Master_SSL_Cert: 
            Master_SSL_Cipher: 
               Master_SSL_Key: 
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: 1855a1b6-8ea9-11ea-8411-0242ac120007
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 
                Auto_Position: 0
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
1 row in set (0.00 sec)

ERROR: 
No query specified
```

#### 五、验证

在主数据库创建一个test数据库，在从数据库也会自动创建，相反，在从数据库创建则主数据库不会有任何改变，因为从数据库只从主数据库读数据

```
mysql> create database test;
Query OK, 1 row affected (0.03 sec)
```

在从数据库验证，的确多了个test数据库

```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| test               |
+--------------------+
5 rows in set (0.00 sec)
```

#### 六、参考文档

>https://www.extlight.com/2018/03/12/MySQL-%E5%AE%9E%E7%8E%B0%E4%B8%BB%E4%BB%8E%E5%A4%8D%E5%88%B6/
