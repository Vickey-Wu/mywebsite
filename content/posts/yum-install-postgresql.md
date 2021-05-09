---
title: "yum install postgresql"
date: 2021-05-04T03:10:06Z
description:  "yum install postgresql"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/C140886C3DC04974BF3C9540BA55F905?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "postgresql"
  - "docker"
tags:
  - "postgresql"
  - "docker"
  - "yum"
---

#### 启动容器测试

```
[root@ecs-6272 ~]# docker run -itd --name pg  --privileged=true centos:7 /usr/sbin/init
75d46f39e3003b5565f2aa5c125323ec69bcf2f6556dc7e43ed8000dd36b6736
[root@ecs-6272 ~]# docker exec -it pg /bin/bash
```

#### yum 安装postgresql

```
[root@75d46f39e300 /]# yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
......
[root@75d46f39e300 /]# yum install -y postgresql13-server
......
```

##### 创建并更换数据保存目录

```
[root@75d46f39e300 /]# mkdir -p /data/pgdata
[root@75d46f39e300 /]# chown postgres:postgres /data/pgdata/
[root@75d46f39e300 /]# su postgres

bash-4.2$ /usr/pgsql-13/bin/initdb -D /data/pgdata
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "C".
The default database encoding has accordingly been set to "SQL_ASCII".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /data/pgdata ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default time zone ... UTC
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok

initdb: warning: enabling "trust" authentication for local connections
You can change this by editing pg_hba.conf or using the option -A, or
--auth-local and --auth-host, the next time you run initdb.

Success. You can now start the database server using:

    /usr/pgsql-13/bin/pg_ctl -D /data/pgdata -l logfile start

bash-4.2$ exit
exit
```

#### 修改yum安装生成的postgresql的service配置文件将目录改为更换后的目录


>更换目录后，配置文件和日志文件就会保存在这个目录下。我这里是/data/pgdata

```
[root@75d46f39e300 /]# vi /usr/lib/systemd/system/postgresql-13.service
......
Environment=PGDATA=/data/pgdata/
......
```

#### 配置开机启动

```
[root@75d46f39e300 /]# systemctl enable postgresql-13
Created symlink from /etc/systemd/system/multi-user.target.wants/postgresql-13.service to /usr/lib/systemd/system/postgresql-13.service.
[root@75d46f39e300 /]# systemctl start postgresql-13
[root@75d46f39e300 /]# systemctl status postgresql-13
● postgresql-13.service - PostgreSQL 13 database server
   Loaded: loaded (/usr/lib/systemd/system/postgresql-13.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-05-04 08:43:37 UTC; 47s ago
     Docs: https://www.postgresql.org/docs/13/static/
  Process: 298 ExecStartPre=/usr/pgsql-13/bin/postgresql-13-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
 Main PID: 303 (postmaster)
   CGroup: /system.slice/docker-75d46f39e3003b5565f2aa5c125323ec69bcf2f6556dc7e43ed8000dd36b6736.scope/system.slice/docker-75d46f39e3003b5565f2aa5c125323ec69bcf2f6556dc7e43ed8000dd36b6736.scope/system.slice/postgresql-13.service
           ├─303 /usr/pgsql-13/bin/postmaster -D /data/pgdata
           ├─304 postgres: logger
           ├─306 postgres: checkpointer
           ├─307 postgres: background writer
           ├─308 postgres: walwriter
           ├─309 postgres: autovacuum launcher
           ├─310 postgres: stats collector
           └─311 postgres: logical replication launcher
           ‣ 303 /usr/pgsql-13/bin/postmaster -D /data/pgdata

May 04 08:43:37 75d46f39e300 systemd[1]: Starting PostgreSQL 13 database server...
May 04 08:43:37 75d46f39e300 systemd[1]: Started PostgreSQL 13 database server.
```

#### 配置外网可访问

>默认只有本机127.0.0.1可以访问数据库，在`pg_hba.conf`后面增加一行`0.0.0.0/0`，在`postgresql.conf`修改为`listen_addresses = '*'`后，重启postgresql服务

>注意：配置未改为all会报错：`user "postgres", database "postgres", SSL off`。postgre未配置密码会报错：`fe_sendauth: no password supplied`
```
[root@75d46f39e300 /]# netstat -lnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 127.0.0.1:5432          0.0.0.0:*               LISTEN      303/postmaster


[root@75d46f39e300 /]# cd /data/pgdata/
[root@75d46f39e300 pgdata]# vi pg_hba.conf
......
host    all     all             0.0.0.0/0            	md5
......

[root@75d46f39e300 pgdata]# vi postgresql.conf
......
listen_addresses = '*'		# what IP address(es) to listen on;
......

[root@75d46f39e300 pgdata]# netstat -lnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:5432            0.0.0.0:*               LISTEN      401/postmaster
tcp6       0      0 :::5432                 :::*                    LISTEN      401/postmaster
```

#### 设置密码并重启服务生效

```
[root@6a164d49e256 pgdata]# su postgres
bash-4.2$ psql
postgres=# alter role postgres with password 'mypasswd';
ALTER ROLE
postgres=# \q
bash-4.2$ exit

[root@6a164d49e256 pgdata]# systemctl restart postgresql-13
```

#### 修改字符编码为utf-8

```
[root@6a164d49e256 pgdata]# su  postgres
```
执行下面的sql语句
```
update pg_database set datallowconn = TRUE where datname = 'template0';

update pg_database set datistemplate = FALSE where datname = 'template1';

drop database template1;

create database template1 with template = template0 encoding = 'UTF8';

update pg_database set datistemplate = TRUE where datname = 'template1';

update pg_database set datallowconn = FALSE where datname = 'template0';
```

不然报这个错

```
ERROR: new encoding (UTF8) is incompatible with the encoding of the template database (SQL_ASCII)
```

#### 参考文章

>`https://www.postgresql.org/download/linux/redhat/`

>`https://blog.csdn.net/feinifi/article/details/96474115`

>`https://www.postgresql.org/ftp/pgadmin/pgadmin4/v5.2/windows/`

>`https://blog.csdn.net/qq_35624642/article/details/81985940`
