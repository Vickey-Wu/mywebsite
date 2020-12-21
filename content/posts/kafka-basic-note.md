---
title: "kafka基础入门笔记"
date: 2020-12-10T03:10:06Z
description:  "kafka基础入门笔记"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/E356E5CED4294D23888BCE36326FD4D0?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "kafka"
  - "docker"
tags:
  - "kafka"
  - "docker"
---

#### 概念

kafka是一个高性能（TB级数据可在常数时间访问）、可扩展（支持在线水平扩展）、高吞吐（10k/s）、高容错（数据持久化到磁盘）的开源分布式事件流消息系统。

- broker：经纪人，kafka集群包含若干个服务器节点，这些节点被称为broker，用来存储topic数据。
- topic: 主题，使用主题来表示消息的类别。
- broker controller：经纪人控制器，kafka集群中多个broker中有一个会被选举为broker controller，负责管理整个集群的partition。
- partitions：分区，主题中的消息可以被分割的若干分区，一个分区对应一个目录，分区内部消息是有序的，但分区间的消息是无序的。
- replizcas of partition：分区副本，为防止消息丢失创建的分区的备份。
- partition leader：主副本，如分区有有多个副本，其中只能有一个leader副本，负责读写消息。
- partition follower：副本跟随者，所有follower从leader同步消息，它们是主备关系而非主从关系。
- segment：分段，分区的消息可以被分未若干分段，每个分段文件大小相等。
- producer：生产者，生产消息存储到topic的某个分区。
- consumer：消费者，消费生产者生产的消息。
- consumer group：消费者组，组内有多个消费者，它们共享公共的group ID，一起消费主题的所有分区，同组内只有一个消费者消费某一条消息，不会多个消费同一条。
- current offset：当前偏移量，它是指向Kafka已经发送给消费者的最后一条记录的指针，它用来确保消费过的数据不会被再次消费
- committed offset：已提交偏移量，它是指向消费者已成功消费的最后一条记录的指针，它用于避免在分区重新平衡（rebalance）时将相同的记录重新发送给新的消费者。
- rebalance：分区再平衡，指消费者组中的consumer数量或topic中的partition数量发生变化时partition重新划分的过程。
- ZooKeeper：消息注册中心，负责维护和协调broker，负责broker controller的选举，管理offset。

#### 应用场景

1.用户活动跟踪
2.日志收集
3.限流削峰

#### kafka优点

1.解耦
2.冗余
3.可扩展
4.削峰
5.可恢复
6.顺序处理
7.异步通信

#### kafka单点部署

kafka需要java 8+的环境，为了不破坏我宿主机的环境，拉个`openjdk:8`镜像来体验kafka。

```
[root@ecs-6272 ~]# docker pull openjdk:8
[root@ecs-6272 ~]# docker run -itd --name kafka openjdk:8
7a8603e547f8a1f6459324361b0e7d1428c0b6e30df2a6f137a55f6be9e39057
```

去`https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/`下载自己想要的kafka版本并复制到容器里面解压缩

```
[root@ecs-6272 ~]# wget https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/2.6.0/kafka_2.13-2.6.0.tgz
[root@ecs-6272 ~]# docker cp kafka_2.13-2.6.0.tgz kafka:/home
[root@ecs-6272 ~]# docker exec -it kafka /bin/bash
root@7a8603e547f8:/# cd /home
root@7a8603e547f8:/home# tar -xzf kafka_2.13-2.6.0.tgz 
root@7a8603e547f8:/home# ls
kafka_2.13-2.6.0  kafka_2.13-2.6.0.tgz
```

启动zookeeper服务

```
root@7a8603e547f8:/home# cd kafka_2.13-2.6.0
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/zookeeper-server-start.sh config/zookeeper.properties
......
[2020-12-14 06:09:27,657] INFO Created server with tickTime 3000 minSessionTimeout 6000 maxSessionTimeout 60000 datadir /tmp/zookeeper/version-2 snapdir /tmp/zookeeper/version-2 (org.apache.zookeeper.server.ZooKeeperServer)
[2020-12-14 06:09:27,665] INFO Using org.apache.zookeeper.server.NIOServerCnxnFactory as server connection factory (org.apache.zookeeper.server.ServerCnxnFactory)
[2020-12-14 06:09:27,669] INFO Configuring NIO connection handler with 10s sessionless connection timeout, 1 selector thread(s), 4 worker threads, and 64 kB direct buffers. (org.apache.zookeeper.server.NIOServerCnxnFactory)
[2020-12-14 06:09:27,680] INFO binding to port 0.0.0.0/0.0.0.0:2181 (org.apache.zookeeper.server.NIOServerCnxnFactory)
[2020-12-14 06:09:27,699] INFO zookeeper.snapshotSizeFactor = 0.33 (org.apache.zookeeper.server.ZKDatabase)
[2020-12-14 06:09:27,704] INFO Snapshotting: 0x0 to /tmp/zookeeper/version-2/snapshot.0 (org.apache.zookeeper.server.persistence.FileTxnSnapLog)
[2020-12-14 06:09:27,708] INFO Snapshotting: 0x0 to /tmp/zookeeper/version-2/snapshot.0 (org.apache.zookeeper.server.persistence.FileTxnSnapLog)
[2020-12-14 06:09:27,727] INFO Using checkIntervalMs=60000 maxPerMinute=10000 (org.apache.zookeeper.server.ContainerManager)
```

打开一个新终端进入容器启动`kafka broker`服务

```
[root@ecs-6272 ~]# docker exec -it kafka /bin/bash
root@7a8603e547f8:/# cd /home/kafka_2.13-2.6.0
root@7a8603e547f8:/home/kafka_2.13-2.6.0#  bin/kafka-server-start.sh config/server.properties
......
[2020-12-14 06:19:45,886] INFO Kafka version: 2.6.0 (org.apache.kafka.common.utils.AppInfoParser)
[2020-12-14 06:19:45,886] INFO Kafka commitId: 62abe01bee039651 (org.apache.kafka.common.utils.AppInfoParser)
[2020-12-14 06:19:45,886] INFO Kafka startTimeMs: 1607926785876 (org.apache.kafka.common.utils.AppInfoParser)
[2020-12-14 06:19:45,888] INFO [KafkaServer id=0] started (kafka.server.KafkaServer)
```

#### 创建topic来存储events

Kafka是一个分布式事件流平台，可让您跨多台计算机读取，写入，存储和处理events（在文档中也称为records或messages）。`topic`类似于文件系统中的`文件夹`，`events`是该文件夹中的`文件`。所以在编写第一个event之前，必须创建一个topic。打开一个新终端来创建topic

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092
Created topic quickstart-events.
```

同时kafka服务的日志会输出创建topic的信息

```
[2020-12-14 07:06:42,532] INFO Creating topic quickstart-events with configuration {} and initial partition assignment HashMap(0 -> ArrayBuffer(0)) (kafka.zk.AdminZkClient)
[2020-12-14 07:06:42,665] INFO [ReplicaFetcherManager on broker 0] Removed fetcher for partitions Set(quickstart-events-0) (kafka.server.ReplicaFetcherManager)
[2020-12-14 07:06:42,744] INFO [Log partition=quickstart-events-0, dir=/tmp/kafka-logs] Loading producer state till offset 0 with message format version 2 (kafka.log.Log)
[2020-12-14 07:06:42,753] INFO Created log for partition quickstart-events-0 in /tmp/kafka-logs/quickstart-events-0 with properties {compression.type -> producer, message.downconversion.enable -> true, min.insync.replicas -> 1, segment.jitter.ms -> 0, cleanup.policy -> [delete], flush.ms -> 9223372036854775807, segment.bytes -> 1073741824, retention.ms -> 604800000, flush.messages -> 9223372036854775807, message.format.version -> 2.6-IV0, file.delete.delay.ms -> 60000, max.compaction.lag.ms -> 9223372036854775807, max.message.bytes -> 1048588, min.compaction.lag.ms -> 0, message.timestamp.type -> CreateTime, preallocate -> false, min.cleanable.dirty.ratio -> 0.5, index.interval.bytes -> 4096, unclean.leader.election.enable -> false, retention.bytes -> -1, delete.retention.ms -> 86400000, segment.ms -> 604800000, message.timestamp.difference.max.ms -> 9223372036854775807, segment.index.bytes -> 10485760}. (kafka.log.LogManager)
[2020-12-14 07:06:42,754] INFO [Partition quickstart-events-0 broker=0] No checkpointed highwatermark is found for partition quickstart-events-0 (kafka.cluster.Partition)
[2020-12-14 07:06:42,755] INFO [Partition quickstart-events-0 broker=0] Log loaded for partition quickstart-events-0 with initial high watermark 0 (kafka.cluster.Partition)
```

不带参数运行脚本来查看参数使用方法

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh 
Create, delete, describe, or change a topic.
Option                                   Description                            
------                                   -----------                            
--create                                 Create a new topic.
......
```

`--describe`查看指定topic的详情，参数`--topic, --bootstrap-server`都是必须的

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092
Topic: quickstart-events	PartitionCount: 1	ReplicationFactor: 1	Configs: segment.bytes=1073741824
	Topic: quickstart-events	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
```

#### 向topic写入events

新开一个终端来运行生产者客户端，将一些events写入topic。默认情况下，您输入的每一行都写入一个单独的event到topic。按CTRL+C终止。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-console-producer.sh --topic quickstart-events --bootstrap-server localhost:9092
>first event  
>second event
```

新开一个终端来运行消费者客户端，运行后就会读取到生产者发送过来的全部event。按CTRL+C终止。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-console-consumer.sh --topic quickstart-events --from-beginning --bootstrap-server localhost:9092
first event
second event
^CProcessed a total of 2 messages
```

#### 设置特定topic过期时间

所有topic默认保留时间为`168小时`也就是`7天`，可以在`server.properties`修改`log.retention.hours`。以下设置单个过期时间并查看，`retention.ms=86400000`为1天后过期

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-configs.sh --alter --entity-name quickstart-events --entity-type topics --bootstrap-server localhost:9092 --add-config retention.ms=86400000
Completed updating config for topic quickstart-events.

root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-configs.sh --describe --entity-name quickstart-events --entity-type topics --bootstrap-server localhost:9092
Dynamic configs for topic quickstart-events are:
  retention.ms=86400000 sensitive=false synonyms={DYNAMIC_TOPIC_CONFIG:retention.ms=86400000}
```

#### 删除特定topic

一.如果在kafka的配置文件`server.properties`设置了参数`delete.topic.enable=true`，使用命令可以直接删除，kafka配置文件`server.properties`中`log.dirs=/tmp/kafka-logs/`配置的是存放topic的目录，删除后topic名后面会被标记为`delete`，在zookeeper列表里也没有这个topic的信息了；

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/quickstart-events-0/
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --list --zookeeper localhost:2181
__consumer_offsets
quickstart-events

root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic quickstart-events
Topic quickstart-events is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.

root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/quickstart-events-0.621f8fa4493e4f4fa968fa2cda1291e1-delete/
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --list --zookeeper localhost:2181
__consumer_offsets
```

二.如果没有设置参数使用命令，删除后topic名后面会被标记不会被标记为`delete`，用`bin/zookeeper-shell.sh localhost:2181`进入zookeeper用`ls /brokers/topics`查看也会显示还在列表中。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/quickstart-events-0/
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --list --zookeeper localhost:2181
__consumer_offsets
quickstart-events

root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic quickstart-events
Topic quickstart-events is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --list --zookeeper localhost:2181
__consumer_offsets
quickstart-events - marked for deletion
```

要彻底删除还需要执行以下步骤。

1.停止生产者，消费者，kafka服务。

2.删除kafka下的topic。找到配置文件`server.properties`中`log.dirs=/tmp/kafka-logs/`目录下的topic目录，我这里的是`/tmp/kafka-logs/quickstart-events-0/`

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# rm -rf /tmp/kafka-logs/quickstart-events-0/
```

3.删除zookeeper里面要删除的topic。用`bin/zookeeper-shell.sh localhost:2181`进入zookeeper客户端交互模式操作，可以输入`help`查看命令操作提示。执行`deleteall /brokers/topics/quickstart-events`后再次查看可以看到topic已经没有了，输入quit退出。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/zookeeper-shell.sh localhost:2181
Connecting to localhost:2181
Welcome to ZooKeeper!
JLine support is disabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
ls /brokers/topics
[__consumer_offsets, quickstart-events]
rmr /brokers/topics/quickstart-events
The command 'rmr' has been deprecated. Please use 'deleteall' instead.
ls /brokers/topics
[__consumer_offsets]
quit
```

4.启动kafka服务，生产者，消费者

#### kafka集群部署

跟上面步骤一样先启动zookeeper

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/zookeeper-server-start.sh config/zookeeper.properties
```

复制3份kafka server.properties配置并修改成不同的id，目录，端口。

server_9092

```
broker.id=0
log.dirs=/tmp/kafka-logs/9092
listeners=PLAINTEXT://localhost:9092
advertised.listeners=PLAINTEXT://localhost:9092
default.replication.factor =3
```

server_9093

```
broker.id=1
log.dirs=/tmp/kafka-logs/9093
listeners=PLAINTEXT://localhost:9093
advertised.listeners=PLAINTEXT://localhost:9093
default.replication.factor =3
```

server_9094

```
broker.id=2
log.dirs=/tmp/kafka-logs/9094
listeners=PLAINTEXT://localhost:9094
advertised.listeners=PLAINTEXT://localhost:9094
default.replication.factor =3
```

启动3个kafka节点

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-server-start.sh config/server_9092.properties root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-server-start.sh config/server_9093.properties root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-server-start.sh config/server_9094.properties 
```
```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/
9092  9093  9094
```

向topic: quickstart-events 写消息，存入到`localhost:9092,localhost:9094`，但默认配置中partition为1，所以只会存到其中一个broker中，这里存到了ID为2的broker中，也就是9094的broker。报错`LEADER_NOT_AVAILABLE`因为没有先创建topic，先创建在使用就没有报错。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-console-producer.sh --topic quickstart-events  --bootstrap-server localhost:9092,localhost:9094
>1
[2020-12-21 07:47:04,097] WARN [Producer clientId=console-producer] Error while fetching metadata with correlation id 3 : {quickstart-events=LEADER_NOT_AVAILABLE} (org.apache.kafka.clients.NetworkClient)
[2020-12-21 07:47:04,222] WARN [Producer clientId=console-producer] Error while fetching metadata with correlation id 4 : {quickstart-events=LEADER_NOT_AVAILABLE} (org.apache.kafka.clients.NetworkClient)


root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --describe --zookeeper localhost:2181
Topic: quickstart-events	PartitionCount: 1	ReplicationFactor: 1	Configs: 
	Topic: quickstart-events	Partition: 0	Leader: 2	Replicas: 2	Isr: 2


root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/909*
/tmp/kafka-logs/9092:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  recovery-point-offset-checkpoint  replication-offset-checkpoint

/tmp/kafka-logs/9093:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  recovery-point-offset-checkpoint  replication-offset-checkpoint

/tmp/kafka-logs/9094:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  quickstart-events-0  recovery-point-offset-checkpoint	replication-offset-checkpoint
```

修改所有的kafka节点配置文件中partition值为3，跟broker数量相等，重启kafka，再创建新的topic：test-cluster，可以看到3个broker目录都有了这个topic的数据。副本数都是1。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --create --topic quickstart-events1 --bootstrap-server localhost:9092,localhost:9094
Created topic quickstart-events1.

root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-console-producer.sh --topic test-cluster  --bootstrap-server localhost:9092,localhost:9094
>1

root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --describe --zookeeper localhost:2181
Topic: quickstart-events	PartitionCount: 1	ReplicationFactor: 1	Configs: 
	Topic: quickstart-events	Partition: 0	Leader: 2	Replicas: 2	Isr: 2
Topic: test-cluster	PartitionCount: 3	ReplicationFactor: 1	Configs: 
	Topic: test-cluster	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
	Topic: test-cluster	Partition: 1	Leader: 1	Replicas: 1	Isr: 1
	Topic: test-cluster	Partition: 2	Leader: 2	Replicas: 2	Isr: 2

root@7a8603e547f8:/home/kafka_2.13-2.6.0# ls /tmp/kafka-logs/909*
/tmp/kafka-logs/9092:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  recovery-point-offset-checkpoint  replication-offset-checkpoint  test-cluster-0

/tmp/kafka-logs/9093:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  recovery-point-offset-checkpoint  replication-offset-checkpoint  test-cluster-1

/tmp/kafka-logs/9094:
cleaner-offset-checkpoint  log-start-offset-checkpoint	meta.properties  quickstart-events-0  recovery-point-offset-checkpoint	replication-offset-checkpoint  test-cluster-2
```

上面例子的副本数都是1，因为kafka默认副本数为1，在配置文件添加参数`default.replication.factor =2`（副本数与broker数一致最佳），新生成的topic副本数就会更改为`ReplicationFactor: 2`。Isr(In-Sync Replicas)表示已从leader partition同步的副本。

```
root@7a8603e547f8:/home/kafka_2.13-2.6.0# bin/kafka-topics.sh --describe --zookeeper localhost:2181
Topic: test-cluster-again	PartitionCount: 3	ReplicationFactor: 2	Configs: 
	Topic: test-cluster-again	Partition: 0	Leader: 0	Replicas: 0,1	Isr: 0,1
	Topic: test-cluster-again	Partition: 1	Leader: 1	Replicas: 1,2	Isr: 1,2
	Topic: test-cluster-again	Partition: 2	Leader: 2	Replicas: 2,0	Isr: 2,0
```

#### 参考文章

>`https://kafka.apache.org/quickstart`

>`https://jaceklaskowski.gitbooks.io/apache-kafka/content/kafka-topic-deletion.html`

>`https://stackoverflow.com/questions/33537950/how-to-delete-a-topic-in-apache-kafka`

>`https://mp.weixin.qq.com/s/R1en4V0Tlwlpt102BjotoA`
