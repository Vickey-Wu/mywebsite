---
title: "k8s安装elk及使用"
date: 2020-11-30T03:10:06Z
description:  "k8s安装elk及使用"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/1DEE64A6D9A84BA0BC3C7A02725B811D?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "helm"
  - "elk"
tags:
  - "helm"
  - "elk"
---

#### 添加官方仓库

```
[root@ecs-6272 tmp]# helm repo add elastic https://helm.elastic.co
"elastic" has been added to your repositories
[root@ecs-6272 tmp]# helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "elastic" chart repository
Update Complete. ⎈ Happy Helming!⎈ 

[root@ecs-6272 tmp]# helm search repo elastic
NAME                     	CHART VERSION	APP VERSION	DESCRIPTION                                       
elastic/elasticsearch    	7.10.0       	7.10.0     	Official Elastic helm chart for Elasticsearch     
elastic/apm-server       	7.10.0       	7.10.0     	Official Elastic helm chart for Elastic APM Server
elastic/eck-operator     	1.3.0        	1.3.0      	A Helm chart for deploying the Elastic Cloud on...
elastic/eck-operator-crds	1.3.0        	1.3.0      	A Helm chart for installing the ECK operator Cu...
elastic/filebeat         	7.10.0       	7.10.0     	Official Elastic helm chart for Filebeat          
elastic/kibana           	7.10.0       	7.10.0     	Official Elastic helm chart for Kibana            
elastic/logstash         	7.10.0       	7.10.0     	Official Elastic helm chart for Logstash          
elastic/metricbeat       	7.10.0       	7.10.0     	Official Elastic helm chart for Metricbeat  
```

#### 配置动态卷来持久化数据

1.安装nfs

如果用云服务商的nas可忽略，如果使用自建nfs首先要安装好nfs服务，自行百度或参考[k8s实践记录（二）](https://mp.weixin.qq.com/s/bZWLAojB-XSDmKQB23oToQ)中nfs安装。我这里挂载的共享目录是`/share`，将`/share/dynamic`子目录作为`elk`的动态卷目录。

2.配置nfs动态卷

所需yaml文件从[github仓库](https://github.com/Vickey-Wu/nfs-provisioner)复制过来修改一下**nfs变量your_nfs_server_ip, your_nfs_share_dir，还有namespace改为跟安装elk的namespace一致**，然后`kubectl apply -f .`安装即可。

>`https://github.com/Vickey-Wu/nfs-provisioner`

#### 安装elasticsearch

Elasticsearch: 用来存储数据，索引数据

>由于我的服务器性能不够，就用`kubectl taint node xxx node-role.kubernetes.io/master-`将master节点设为可调度，使用`helm show values`将组件的`values.yaml`的内容拉下来修改配置，将es最少3个master节点改为了1个，还有CPU、内存等资源限制改小了，像kibana等其他组件按照同样的方法修改配置。服务器资源足够的话就无需改动，直接`helm install elastic/xxx`就行了。

```
[root@ecs-6272 project]# helm show values elastic/elasticsearch>/tmp/elastic-values.yaml

[root@ecs-6272 project]# helm install es elastic/elasticsearch -f /tmp/elastic-values.yaml 
NAME: es
LAST DEPLOYED: Tue Nov 24 16:56:45 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Watch all cluster members come up.
  $ kubectl get pods --namespace=default -l app=elasticsearch-master -w
2. Test cluster health using Helm test.
  $ helm test es
```

查看es持久化是否正常。

```
[root@ecs-6272 project]# kubectl get pvc
NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
elasticsearch-master-elasticsearch-master-0   Bound    pvc-27a12caf-6d98-4b1c-9919-b164cae161f2   30Gi       RWO
[root@ecs-6272 project]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                 STORAGECLASS          REASON   AGE
pvc-27a12caf-6d98-4b1c-9919-b164cae161f2   30Gi       RWO            Delete           Bound    default/elasticsearch-master-elasticsearch-master-0   managed-nfs-storage            27m
[root@ecs-6272 project]# ls /share/dynamic/
default-elasticsearch-master-elasticsearch-master-0-pvc-27a12caf-6d98-4b1c-9919-b164cae161f2 
```

直接访问es的svc`10.110.254.26:9200`验证是否正常，或`kubectl edit svc elasticsearch-master`将`ClusterIP`改为`NodePort`指定端口在外网访问。

```
[root@ecs-6272 project]# kubectl get pod
NAME                                      READY   STATUS    RESTARTS   AGE
elasticsearch-master-0                    1/1     Running   0          35s
nfs-client-provisioner-7fc4bcf9c7-4vbvf   1/1     Running   0          16m

[root@ecs-6272 project]# kubectl get svc
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
elasticsearch-master            NodePort    10.110.254.26   <none>        9200:30200/TCP,9300:30575/TCP   27m
elasticsearch-master-headless   ClusterIP   None            <none>        9200/TCP,9300/TCP               27m
kubernetes                      ClusterIP   10.96.0.1       <none>        443/TCP                         24h

[root@ecs-6272 project]# curl 10.110.254.26:9200
{
  "name" : "elasticsearch-master-0",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "Rv4QGubPTjq9g2Z6irkyEg",
  "version" : {
    "number" : "7.10.0",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "51e9d6f22758d0374a0f3f5c6e8f3a7997850f96",
    "build_date" : "2020-11-09T21:30:33.964949Z",
    "build_snapshot" : false,
    "lucene_version" : "8.7.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

![elasticsearch](https://note.youdao.com/yws/api/personal/file/B562D51E4A234C49990735EBAEA7B371?method=download&shareKey=59f7bf8aad530b8eeb611aaf4001e09c)

#### 安装kibana

Kibana:用来可视化数据，分析数据，下面步骤会做示例

![kibana](https://note.youdao.com/yws/api/personal/file/AC82D066B9D245FD86B3FD90322B0E88?method=download&shareKey=f39dfde21c7e78cade7d614039ab040c)


#### 安装Metricbeat

Metricbeat会在每个节点部署metricbeat和kube-state-metrics用来收集发送k8s集群中各个组件资源及服务器的数据给es


```
[root@ecs-6272 ~]# kubectl get pod -o wide
NAME                                      READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
elasticsearch-master-0                    1/1     Running   0          40m   10.244.0.5   ecs-6272   <none>           <none>
kb-kibana-75f5664646-x8vq5                1/1     Running   0          39m   10.244.1.5   vickey     <none>           <none>
mb-kube-state-metrics-75bf485965-njcs2    1/1     Running   0          29m   10.244.1.7   vickey     <none>           <none>
mb-metricbeat-bcc2c                       1/1     Running   0          29m   10.244.1.6   vickey     <none>           <none>
mb-metricbeat-metrics-7dbcb4674c-9s42t    1/1     Running   0          29m   10.244.1.8   vickey     <none>           <none>
mb-metricbeat-rpnxm                       1/1     Running   0          29m   10.244.0.6   ecs-6272   <none>           <none>
nfs-client-provisioner-7fc4bcf9c7-4vbvf   1/1     Running   0          40m   10.244.1.3   vickey     <none>           <none>

[root@ecs-6272 project]# kubectl get svc
NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                         AGE
elasticsearch-master            NodePort    10.110.254.26    <none>        9200:30200/TCP,9300:30575/TCP   76m
elasticsearch-master-headless   ClusterIP   None             <none>        9200/TCP,9300/TCP               76m
kb-kibana                       NodePort    10.105.228.153   <none>        5601:30300/TCP                  31m
kubernetes                      ClusterIP   10.96.0.1        <none>        443/TCP                         25h
mb-kube-state-metrics           ClusterIP   10.104.204.111   <none>        8080/TCP                        29m52s
```


创建一个使用metricbeat的索引样板index pattern。`搜索框输入Management -> Kibana中的Index Patterns -> Create index pattern ->输入metricbeat* -> 选择@timestamp -> 完成`。然后在`搜索框输入Discover点击跳转过去`就可以看到metricbeat收集的数据了。

![metricbeat](https://note.youdao.com/yws/api/personal/file/5E1788F813D643C5A9EF59F746CB6003?method=download&shareKey=3160a009b131e2664114b9374b062c02)


#### 安装filebeat

Filebeat: 收集应用日志。在搜索框搜索log跳转过去就可以看到filebeat收集的日志了。也可以跟metricbeat一样，添加索引后在discover查询过滤自己想要的数据。

![filebeat-logs](https://note.youdao.com/yws/api/personal/file/1F14C4A76FED47E894701C9C8981F6A5?method=download&shareKey=7ab811e0a36f4a30b866e7c53a7ef8de)

#### 添加自定义数据

添加之前[爬取的电影天堂的数据](https://mp.weixin.qq.com/s/3WWwgIdjcUuoN4jCGPsPsQ)到kibana分析。首先得先安装logstash，按照es一样获取values.yaml修改配置，为logstash配置pipeline，读取mysql数据库里面的数据。由于官方的logstash没有mysql连接的jar包，就自己下了打包进官方镜像，我的数据存放在mysql8，所以下的是`mysql 8`的jar包。替换官方镜像为我的镜像`vickeywu/logstash:mysql8-connector`然后使用helm install即可。启动之后跟metricbeat一样操作创建索引，就可以在discover页面看到从数据库取出来的数据了。

```
logstashPipeline:
  logstash.conf: |
    input {
      jdbc {
          jdbc_driver_library => "/usr/share/logstash/logstash-core/lib/jars/mysql-connector-java.jar"
          jdbc_driver_class => "com.mysql.jdbc.Driver"
          jdbc_connection_string => "jdbc:mysql://x.x.x.x:3306/yourdb"
          jdbc_user => "dbuser"
          jdbc_password => "dbpassword"
          schedule => "*/5 * * * *"
          statement => "select * from yourtable"
      }
    }
    output {
        elasticsearch {
            hosts => ["http://elasticsearch-master:9200"]
            index => "movie"
            #user => "elastic"
            #password => "elastic"
        }
    }

image: "vickeywu/logstash"
imageTag: "mysql8-connector"
```

![logstash-self-defined-data](https://note.youdao.com/yws/api/personal/file/0F7318870BAE420F92F1A3968E7E53C6?method=download&shareKey=669341101b009f95e407550f6016712f)

#### 所有组件

```
[root@ecs-6272 local]# kubectl get pod -o wide
NAME                                      READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
elasticsearch-master-0                    1/1     Running   0          42h   10.244.0.5    ecs-6272   <none>           <none>
fb-filebeat-l4mnl                         1/1     Running   0          53m   10.244.0.8    ecs-6272   <none>           <none>
fb-filebeat-xpmfx                         1/1     Running   0          53m   10.244.1.14   vickey     <none>           <none>
kb-kibana-75f5664646-x8vq5                1/1     Running   0          41h   10.244.1.5    vickey     <none>           <none>
ls-logstash-0                             1/1     Running   0          18m   10.244.0.62   ecs-6272   <none>           <none>
mb-kube-state-metrics-75bf485965-njcs2    1/1     Running   0          41h   10.244.1.7    vickey     <none>           <none>
mb-metricbeat-bcc2c                       1/1     Running   0          41h   10.244.1.6    vickey     <none>           <none>
mb-metricbeat-metrics-7dbcb4674c-9s42t    1/1     Running   0          41h   10.244.1.8    vickey     <none>           <none>
mb-metricbeat-rpnxm                       1/1     Running   0          41h   10.244.0.6    ecs-6272   <none>           <none>
nfs-client-provisioner-7fc4bcf9c7-4vbvf   1/1     Running   0          42h   10.244.1.3    vickey     <none>           <none>
```

#### 参考文章

>`https://itnext.io/deploy-elastic-stack-on-kubernetes-1-15-using-helm-v3-9105653c7c8`

>`https://logz.io/blog/deploying-the-elk-stack-on-kubernetes-with-helm/`

>`https://www.elastic.co/beats/`

>`https://github.com/dimMaryanto93/docker-logstash-input-jdbc`

>`https://www.cnblogs.com/sanduzxcvbnm/p/12869858.html`
