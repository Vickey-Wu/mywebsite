---
title: "docker部署canal"
date: 2020-05-13T03:10:06Z
description: "docker部署canal"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/B4D3E059472E4BCD8756FF3E5A0046EA?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "docker"
  - "namespace"
  - "cgroups"
  - "rootfs"
---

#### 一、canal-admin-mysql

##### 1. 自建mysql（使用阿里云rds看下一步）

1. my.cnf

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
server-id       = 888
sync-binlog     = 1
character-set-server = utf8

# Custom config should go here
!includedir /etc/mysql/conf.d/
```

2. start-mysql.sh

```
docker run -p 3306:3306 --name canal-admin-mysql -v ${PWD}/my.cnf:/etc/mysql/my.cnf -e MYSQL_ROOT_PASSWORD=yourpasswd -d mysql:5.6
```

3. 创建用户并授权（一定要有SELECT权限）

```
CREATE USER canal IDENTIFIED BY 'yourpasswd';  
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT, SELECT ON *.* TO 'canal'@'%';
FLUSH PRIVILEGES;
```


4. 初始化canal-admin mysql

>可以在官网获取：`https://github.com/alibaba/canal/blob/master/docker/image/canal_manager.sql`

```
CREATE DATABASE /*!32312 IF NOT EXISTS*/ `canal_manager` /*!40100 DEFAULT CHARACTER SET utf8 COLLATE utf8_bin */;

USE `canal_manager`;

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for canal_adapter_config
-- ----------------------------
DROP TABLE IF EXISTS `canal_adapter_config`;
CREATE TABLE `canal_adapter_config` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `category` varchar(45) NOT NULL,
  `name` varchar(45) NOT NULL,
  `status` varchar(45) DEFAULT NULL,
  `content` text NOT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for canal_cluster
-- ----------------------------
DROP TABLE IF EXISTS `canal_cluster`;
CREATE TABLE `canal_cluster` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(63) NOT NULL,
  `zk_hosts` varchar(255) NOT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for canal_config
-- ----------------------------
DROP TABLE IF EXISTS `canal_config`;
CREATE TABLE `canal_config` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cluster_id` bigint(20) DEFAULT NULL,
  `server_id` bigint(20) DEFAULT NULL,
  `name` varchar(45) NOT NULL,
  `status` varchar(45) DEFAULT NULL,
  `content` text NOT NULL,
  `content_md5` varchar(128) NOT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sid_UNIQUE` (`server_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for canal_instance_config
-- ----------------------------
DROP TABLE IF EXISTS `canal_instance_config`;
CREATE TABLE `canal_instance_config` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cluster_id` bigint(20) DEFAULT NULL,
  `server_id` bigint(20) DEFAULT NULL,
  `name` varchar(45) NOT NULL,
  `status` varchar(45) DEFAULT NULL,
  `content` text NOT NULL,
  `content_md5` varchar(128) DEFAULT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for canal_node_server
-- ----------------------------
DROP TABLE IF EXISTS `canal_node_server`;
CREATE TABLE `canal_node_server` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cluster_id` bigint(20) DEFAULT NULL,
  `name` varchar(63) NOT NULL,
  `ip` varchar(63) NOT NULL,
  `admin_port` int(11) DEFAULT NULL,
  `tcp_port` int(11) DEFAULT NULL,
  `metric_port` int(11) DEFAULT NULL,
  `status` varchar(45) DEFAULT NULL,
  `modified_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for canal_user
-- ----------------------------
DROP TABLE IF EXISTS `canal_user`;
CREATE TABLE `canal_user` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(31) NOT NULL,
  `password` varchar(128) NOT NULL,
  `name` varchar(31) NOT NULL,
  `roles` varchar(31) NOT NULL,
  `introduction` varchar(255) DEFAULT NULL,
  `avatar` varchar(255) DEFAULT NULL,
  `creation_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------
-- Records of canal_user
-- ----------------------------
BEGIN;
INSERT INTO `canal_user` VALUES (1, 'admin', '6BB4837EB74329105EE4568DDA7DC67ED2CA2AD9', 'Canal Manager', 'admin', NULL, NULL, '2019-07-14 00:05:28');
COMMIT;

SET FOREIGN_KEY_CHECKS = 1;
```

##### 2. 使用阿里云rds

>执行上一步自建mysql的3和4步即可

#### 二、部署canal-admin

>参考官网文档： `https://github.com/alibaba/canal/wiki/Canal-Admin-Docker`

1. 下载canal-admin.sh和application.yml

```
wget https://raw.githubusercontent.com/alibaba/canal/master/docker/run_admin.sh
wget https://raw.githubusercontent.com/alibaba/canal/master/admin/admin-web/src/main/resources/application.yml
```

2. 修改配置application.yml

```
server:
  port: 8089
spring:
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: GMT+8

spring.datasource:
  address: rm-xxxxxxxxxxx.mysql.rds.aliyuncs.com:3306
  database: canal_manager
  username: canal
  password: yourpassword
  driver-class-name: com.mysql.jdbc.Driver
  url: jdbc:mysql://${spring.datasource.address}/${spring.datasource.database}?useUnicode=true&characterEncoding=UTF-8&useSSL=false
  hikari:
    maximum-pool-size: 30
    minimum-idle: 1

canal:
  adminUser: admin
  adminPasswd: yourpassword
```

3. 修改为脚本canal-admin.sh

>修改为1.1.4（默认最新），并挂载配置文件application.yml。

```
cmd="docker run -d -it -h $LOCALHOST $CONFIG -v ${PWD}/application.yml:/home/admin/canal-admin/conf/application.yml --name=canal-admin $VOLUMNS $NET_MODE $PORTS $MEMORY canal/canal-admin:v1.1.4"
```

4. 启动canal-admin

>使用sh启动会报错，改用bash

```
bash  run_admin.sh -e server.port=8089 \
         -e canal.adminUser=admin \
         -e canal.adminPasswd=yourpassword
```

5. 可以正常打开访问yourhost:8089即成功

#### 三、 部署canal-server

1. 下载脚本run.sh

```
https://raw.githubusercontent.com/alibaba/canal/master/docker/run.sh
```

2. 修改run.sh版本为1.1.4

```
cmd="docker run -d -it -h $LOCALHOST $CONFIG --name=canal-server $VOLUMNS $NET_MODE $PORTS $MEMORY canal/canal-server:v1.1.4"
```

3. 启动canal-server

>官网里的密码`4ACFE3202A5FF5CF467898FC58AAB1D615029441`是`admin`的暗文，登录任意数据库执行语句`select password("admin");`便可以得到暗文了。

```
# 以单机模式启动
run.sh -e canal.admin.manager=canal-admin-host:8089 \
         -e canal.admin.port=11110 \
         -e canal.admin.user=admin \
         -e canal.admin.passwd=yourpassword_anwen
         
```
4. instance properties配置

>启动完canal-server后就可以在yourhost:8089的管理页面配置server实例了，添加server使用默认端口11110-11112，添加instance载入模板注意在模板添加黑名单数据库，否则报权限错误无法启动

```
# table black regex
canal.instance.filter.black.regex=mysql..*
```

>canal-server的数据库跟canal-admin的数据库不是同一个，要在配置文件提供连接地址、用户、密码等，载入的模板示例如下

```
#################################################
## mysql serverId , v1.0.26+ will autoGen
# canal.instance.mysql.slaveId=0

# enable gtid use true/false
canal.instance.gtidon=false

# position info
canal.instance.master.address=rm-xxxxxxx.mysql.rds.aliyuncs.com:3306
canal.instance.master.journal.name=
canal.instance.master.position=
canal.instance.master.timestamp=
canal.instance.master.gtid=

# rds oss binlog
canal.instance.rds.accesskey=
canal.instance.rds.secretkey=
canal.instance.rds.instanceId=

# table meta tsdb info
canal.instance.tsdb.enable=true
#canal.instance.tsdb.url=jdbc:mysql://127.0.0.1:3306/canal_tsdb
#canal.instance.tsdb.dbUsername=canal
#canal.instance.tsdb.dbPassword=canal

#canal.instance.standby.address =
#canal.instance.standby.journal.name =
#canal.instance.standby.position =
#canal.instance.standby.timestamp =
#canal.instance.standby.gtid=

# username/password
canal.instance.dbUsername=canal-server-dbuser
canal.instance.dbPassword=canal-server-passwd
canal.instance.defaultDatabaseName = canal-server-db
canal.instance.connectionCharset = UTF-8
# enable druid Decrypt database password
canal.instance.enableDruid=false
#canal.instance.pwdPublicKey=MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALK4BUxdDltRRE5/zXpVEVPUgunvscYFtEip3pmLlhrWpacX7y7GCMo2/JM6LeHmiiNdH1FWgGCpUfircSwlWKUCAwEAAQ==

# table regex
canal.instance.filter.regex=canal-server-db\\..*
# table black regex
canal.instance.filter.black.regex=mysql..*
# table field filter(format: schema1.tableName1:field1/field2,schema2.tableName2:field1/field2)
#canal.instance.filter.field=test1.t_product:id/subject/keywords,test2.t_company:id/name/contact/ch
# table field black filter(format: schema1.tableName1:field1/field2,schema2.tableName2:field1/field2)
#canal.instance.filter.black.field=test1.t_product:subject/product_image,test2.t_company:id/name/contact/ch

# mq config
canal.mq.topic=example
# dynamic topic route by schema or table regex
#canal.mq.dynamicTopic=mytest1.user,mytest2\\..*,.*\\..*
canal.mq.partition=0
# hash partition config
#canal.mq.partitionsNum=3
#canal.mq.partitionHash=test.table:id^name,.*\\..*
#################################################
```

#### 四、问题

canal的服务需要去canal-admin上去读取配置文件，所以canal-admin需要先启动，否则在管理页面server启动会显示断开，启动canal-admin后重启一下canal-server就正常了。

#### 五、参考文档

>`https://github.com/alibaba/canal/wiki/Canal-Admin-Docker`

>`https://laptrinhx.com/docker-installation-stand-alone-canal-2904538782/`

>`https://blog.csdn.net/weixin_40126236/article/details/100777543`
