---
title: "k8s实践记录（六）"
date: 2020-09-10T03:10:06Z
description:  "k8s实践记录（六）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/812FC1B340754E73A6C9371F2E140BB4?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

#### 18.如何使用statefulset部署有状态应用？

首先了解下无状态应用和有状态应用，对比下deployment和statefulset异同点，然后实践下statefulset应用。

#### 无状态应用 vs 有状态应用

- **无状态应用**简单地说就是不用关心它的上下文的应用，如web搜索服务，执行搜索得到结果就行了，如果搜索时意外中断或关闭搜索，则只需重新开始即可，并不会影响你的搜索结果。
- **有状态应用**则是需要关心它的上下文的应用，如银行交易服务，如果有状态事务被中断，其上下文和历史记录会被存储下来，这样就可以或多或少地从上次中断的地方继续。

具体可以参考`https://www.redhat.com/zh/topics/cloud-native-apps/stateful-vs-stateless`

#### deployment vs statefulset

**deployment**

1.多个副本pod的启动没有顺序，pod的名字不是固定的，遇到失败的情况重新生成的pod的名字与原来的pod的名字不一致

2.由默认调度器维持实际数量与期望数量一致

3.可以根据给定更新策略保证更新过程中不可用pod数量在一定访问，默认25%，更新会将所有的pod最终都更新到同一个版本

4.支持一键回滚，如回滚至上一个版本`kubectl rollout undo deploymentname`

**statefulset**

1.多个副本的pod的启动是按顺序的，只有第一个`pod-0`启动状态变为`runnig`才会启动第二个`pod-1`，以此类推；回滚、更新则是逆序的。并且名字都是固定的，遇到失败的情况重新生成的pod的名字与原来的pod的名字是一致的。

2.每个pod都会挂载一个独立的持久卷，不与其他pod共享，当遇到失败、删除重建等情况时就可以保留之前的pod的数据及pod名字

3.在更新时可以根据给定更新策略的partition字段值大小来实现灰度发布，如partition值为2，replicas值为3，则在更新时比2大的pod，也就是pod-2版本将会被更新，小于等于2的pod会保持原来的版本不变，也就是pod-0和pod-1版本不变。


#### statefulset实践 

- statefulset-pv.yaml 

```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-0
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/test-0"
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-1
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/test-1"
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-2
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/test-2"
```

- test-statefulset.yaml 

```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: test-statefulset
  name: test-statefulset-svc
spec:
  type: NodePort
  ports:
    - name: test-statefulset-port
      protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30000
  selector:
    app: statefulset-test
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  creationTimestamp: null
  labels:
    app: statefulset-test
  name: statefulset-test
spec:
  serviceName: test-statefulset-svc             # deployment没有这个字段
  #podManagementPolicy: "Parallel"              # 不写这个字段默认按顺序启动、删除statefulset的pod，如果改为parallel则表示不用按顺序启动、删除
  replicas: 3
  selector:
    matchLabels:
      app: statefulset-test
  updateStrategy:                               # deployment没有这个字段
    type: RollingUpdate
    rollingUpdate:
      partition: 2
  template:
    metadata:
      labels:
        app: statefulset-test
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:                         # deployment没有这个字段
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      #storageClassName: alicloud-disk-ssd      # 云厂商提供的动态卷可以自动创建pv，就无需手动创建pv了。
      resources:
        requests:
          storage: 1Gi
```

- test-deployment.yaml

```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: test-nfs
  name: test-nfs-svc
spec:
  type: NodePort
  ports:
    - name: test-nfs-port
      protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 31000
  selector:
    app: mynginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: mynginx
  name: mynginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mynginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: mynginx
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
status: {}
```

因为我用的虚拟机无动态卷供应，所以需要先手动创建pv（或者使用`ceph`来提供动态卷，之后会实践下）

```
[root@master-1 yamlfiles]# kubectl apply -f  statefulset-pv.yaml 
persistentvolume/test-0 created
persistentvolume/test-1 created
persistentvolume/test-2 created

[root@master-1 ~]# kubectl get pv -w
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM   STORAGECLASS   REASON   AGE
test-0   1Gi        RWO            Retain           Pending                                   0s
test-0   1Gi        RWO            Retain           Available                                   0s
test-1   1Gi        RWO            Retain           Pending                                     0s
test-1   1Gi        RWO            Retain           Available                                   0s
test-2   1Gi        RWO            Retain           Pending                                     0s
test-2   1Gi        RWO            Retain           Available                                   0s
```

然后创建的statefulset会根据volumeClaimTemplates的模板自动为每个pod创建一个pvc，如果已有符合要求的pv，pvc就会绑定pv并有`Available`进入`Bound`状态。绑定后，statefulset的pod就由`Pending`进入`ContainerCreating`，如果能够正常启动的话就进入`Running`状态。可以看到这个创建pod后面都具有序号，它们是按pod-0到pod-2依次创建的。而deployment则是同时启动的，且pod名字是不固定的，使用随机字符命名。

```
[root@master-1 yamlfiles]# kubectl apply -f  test-statefulset.yaml 
service/test-statefulset-svc created
statefulset.apps/statefulset-test created

[root@master-1 ~]# kubectl get pvc -w
NAME                     STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
www-statefulset-test-0   Pending                                                     0s
www-statefulset-test-0   Pending   test-2   0                                        87s
www-statefulset-test-0   Bound     test-2   1Gi        RWO                           87s
www-statefulset-test-1   Pending                                                     0s
www-statefulset-test-1   Pending   test-0   0                                        0s
www-statefulset-test-1   Bound     test-0   1Gi        RWO                           0s
www-statefulset-test-2   Pending                                                     0s
www-statefulset-test-2   Pending   test-1   0                                        0s
www-statefulset-test-2   Bound     test-1   1Gi        RWO                           0s

[root@master-1 ~]# kubectl get pod -w
NAME                                  READY   STATUS        RESTARTS   AGE
statefulset-test-0                    0/1     Pending       0          0s
statefulset-test-0                    0/1     Pending       0          0s
statefulset-test-0                    0/1     Pending       0          90s
statefulset-test-0                    0/1     ContainerCreating   0          90s
statefulset-test-0                    1/1     Running             0          96s
statefulset-test-1                    0/1     Pending             0          0s
statefulset-test-1                    0/1     Pending             0          0s
statefulset-test-1                    0/1     Pending             0          2s
statefulset-test-1                    0/1     ContainerCreating   0          2s
statefulset-test-1                    1/1     Running             0          5s
statefulset-test-2                    0/1     Pending             0          0s
statefulset-test-2                    0/1     Pending             0          0s
statefulset-test-2                    0/1     Pending             0          0s
statefulset-test-2                    0/1     ContainerCreating   0          0s
statefulset-test-2                    1/1     Running             0          3s

[root@master-1 yamlfiles]# kubectl apply -f  test-deployment.yaml 
service/test-nfs-svc created
deployment.apps/mynginx created
[root@master-1 yamlfiles]# kubectl get pod -w
mynginx-5966bfc495-5dx6c              0/1     Pending             0          0s
mynginx-5966bfc495-psr84              0/1     Pending             0          0s
mynginx-5966bfc495-vvmft              0/1     Pending             0          0s
mynginx-5966bfc495-psr84              0/1     Pending             0          0s
mynginx-5966bfc495-vvmft              0/1     Pending             0          0s
mynginx-5966bfc495-5dx6c              0/1     ContainerCreating   0          0s
mynginx-5966bfc495-psr84              0/1     ContainerCreating   0          0s
mynginx-5966bfc495-vvmft              0/1     ContainerCreating   0          0s
mynginx-5966bfc495-5dx6c              1/1     Running             0          3s
mynginx-5966bfc495-vvmft              1/1     Running             0          4s
mynginx-5966bfc495-psr84              1/1     Running             0          9s
```

此时将其中一个pod删除，可以看到它重新创建的pod的名还是原来的pod名，而deployment则使用随机名，但是都会重新分配不同的IP。`statefulset-test-2`由`192.168.1.223`变为了`192.168.1.227`，`mynginx-5966bfc495-hzk9t`由`192.168.1.225`变为了`192.168.1.228`

```
[root@master-1 yamlfiles]# kubectl delete pod statefulset-test-2
pod "statefulset-test-2" deleted
[root@master-1 ~]# kubectl get pod -w -o wide
NAME                                  READY   STATUS        RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
statefulset-test-0                    1/1     Running       0          75m   192.168.1.212   node-1   <none>           <none>
statefulset-test-1                    1/1     Running       0          74m   192.168.1.213   node-1   <none>           <none>
statefulset-test-2                    1/1     Running       0          24m   192.168.1.223   node-1   <none>           <none>
statefulset-test-2                    1/1     Terminating   0          25m   192.168.1.223   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating   0          25m   <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating   0          25m   <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating   0          25m   <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     Pending       0          0s    <none>          <none>   <none>           <none>
statefulset-test-2                    0/1     Pending       0          0s    <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     ContainerCreating   0          0s    <none>          node-1   <none>           <none>
statefulset-test-2                    1/1     Running             0          3s    192.168.1.227   node-1   <none>           <none>

[root@master-1 yamlfiles]# kubectl delete pod mynginx-5966bfc495-hzk9t 
pod "mynginx-5966bfc495-hzk9t" deleted
[root@master-1 ~]# kubectl get pod -w -o wide
mynginx-5966bfc495-5nj7p              1/1     Running       0          82s   192.168.1.226   node-1   <none>           <none>
mynginx-5966bfc495-5tvwk              1/1     Running       0          82s   192.168.1.224   node-1   <none>           <none>
mynginx-5966bfc495-hzk9t              1/1     Running       0          82s   192.168.1.225   node-1   <none>           <none>
mynginx-5966bfc495-hzk9t              1/1     Terminating         0          3m58s   192.168.1.225   node-1   <none>           <none>
mynginx-5966bfc495-nmqds              0/1     Pending             0          0s      <none>          <none>   <none>           <none>
mynginx-5966bfc495-nmqds              0/1     Pending             0          1s      <none>          node-1   <none>           <none>
mynginx-5966bfc495-nmqds              0/1     ContainerCreating   0          1s      <none>          node-1   <none>           <none>
mynginx-5966bfc495-hzk9t              0/1     Terminating         0          4m      192.168.1.225   node-1   <none>           <none>
mynginx-5966bfc495-nmqds              1/1     Running             0          9s      192.168.1.228   node-1   <none>           <none>
mynginx-5966bfc495-hzk9t              0/1     Terminating         0          4m7s    192.168.1.225   node-1   <none>           <none>
mynginx-5966bfc495-hzk9t              0/1     Terminating         0          4m7s    192.168.1.225   node-1   <none>           <none>
```

接着试试更新`statefulset`，将Nginx镜像改为`1.19`，然后apply，由于我在yaml文件里设置了`partition`值为2，replicas值为3，可以看到只更新了比partion大的副本pod，也就是`statefulset-test-2`，而小于等于2的pod，也就是`statefulset-test-0, statefulset-test-1`版本不变。这个`partition`就可以用来实现**灰度发布**的功能，每次分段更新几个pod，没问题后再将`partition`改小直至到0完成全部pod的更新。

```
[root@master-1 yamlfiles]# kubectl apply -f test-statefulset.yaml 
service/test-statefulset-svc unchanged
statefulset.apps/statefulset-test configured
[root@master-1 ~]# kubectl get pod -w
NAME                                  READY   STATUS        RESTARTS   AGE
statefulset-test-0                    1/1     Running       0          53m
statefulset-test-1                    1/1     Running       0          51m
statefulset-test-2                    1/1     Running       0          2m16s
statefulset-test-2                    1/1     Terminating         0          30m
statefulset-test-2                    0/1     Terminating         0          30m
statefulset-test-2                    0/1     Terminating         0          30m
statefulset-test-2                    0/1     Terminating         0          30m
statefulset-test-2                    0/1     Pending             0          0s
statefulset-test-2                    0/1     Pending             0          0s
statefulset-test-2                    0/1     ContainerCreating   0          0s
statefulset-test-2                    1/1     Running             0          7s

[root@master-1 yamlfiles]# kubectl describe pod statefulset-test-2|grep Image
    Image:          nginx:1.19
    Image ID:       docker-pullable://nginx@sha256:2850bbf7ed1bcb88e50c08c424c13fec71cf0a0bf0d496b5481601c69f905534

[root@master-1 yamlfiles]# kubectl describe pod statefulset-test-0|grep Image
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:2850bbf7ed1bcb88e50c08c424c13fec71cf0a0bf0d496b5481601c69f905534
```

然后来看看删除statefulset的pod，逆序删除从结果看不大明显是逆序的，但看`AGE`就可以比较清楚地看出来是逆序了，由`READY: 1/1`变为`0/1`，耗时最长才`Terminating`的是`statefulset-test-0`，花了`31s`，第二的是`statefulset-test-1`花了`30s`，而`statefulset-test-2`在3个中最快，花了`29s`。而deployment基本都是同时结束，耗时都是`41s`。其实更新和删除statefulset的pod，它创建的pvc也都不会被删除的，有状态应用一般需要持久化数据，为了防止误删，默认需要手动删除statefulset创建的pvc。

```
[root@master-1 ~]# kubectl get pod -w -o wide
NAME                                  READY   STATUS        RESTARTS   AGE    IP              NODE     NOMINATED NODE   READINESS GATES
statefulset-test-0                    1/1     Terminating         0          22s    192.168.1.239   node-1   <none>           <none>
statefulset-test-1                    1/1     Terminating         0          21s    192.168.1.240   node-1   <none>           <none>
statefulset-test-2                    1/1     Terminating         0          20s    192.168.1.241   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          23s    192.168.1.239   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          21s    192.168.1.241   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          22s    192.168.1.240   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          30s    192.168.1.240   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          30s    192.168.1.240   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          29s    192.168.1.241   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          29s    192.168.1.241   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          31s    192.168.1.239   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          31s    192.168.1.239   node-1   <none>           <none>



[root@master-1 yamlfiles]# kubectl delete -f test-deployment.yaml 
service "test-nfs-svc" deleted
deployment.apps "mynginx" deleted
[root@master-1 ~]# kubectl get pod -w
mynginx-5966bfc495-fbz97              1/1     Terminating         0          27s    192.168.1.242   node-1   <none>           <none>
mynginx-5966bfc495-b7bb8              1/1     Terminating         0          27s    192.168.1.244   node-1   <none>           <none>
mynginx-5966bfc495-sbqs6              1/1     Terminating         0          27s    192.168.1.243   node-1   <none>           <none>
mynginx-5966bfc495-fbz97              0/1     Terminating         0          28s    192.168.1.242   node-1   <none>           <none>
mynginx-5966bfc495-b7bb8              0/1     Terminating         0          28s    192.168.1.244   node-1   <none>           <none>
mynginx-5966bfc495-sbqs6              0/1     Terminating         0          28s    192.168.1.243   node-1   <none>           <none>
mynginx-5966bfc495-fbz97              0/1     Terminating         0          31s    192.168.1.242   node-1   <none>           <none>
mynginx-5966bfc495-fbz97              0/1     Terminating         0          31s    192.168.1.242   node-1   <none>           <none>
mynginx-5966bfc495-b7bb8              0/1     Terminating         0          41s    192.168.1.244   node-1   <none>           <none>
mynginx-5966bfc495-b7bb8              0/1     Terminating         0          41s    192.168.1.244   node-1   <none>           <none>
mynginx-5966bfc495-sbqs6              0/1     Terminating         0          41s    192.168.1.243   node-1   <none>           <none>
mynginx-5966bfc495-sbqs6              0/1     Terminating         0          41s    192.168.1.243   node-1   <none>           <none>
```

`statefulset`有个字段`podManagementPolicy: "Parallel"`，启用之后`statefulset`的pod就可以和`deployment`一样不按顺序启动、删除了。

```
[root@master-1 ~]# kubectl get pod -w
statefulset-test-0                    0/1     Pending             0          0s     <none>          <none>   <none>           <none>
statefulset-test-0                    0/1     Pending             0          0s     <none>          node-1   <none>           <none>
statefulset-test-1                    0/1     Pending             0          0s     <none>          <none>   <none>           <none>
statefulset-test-1                    0/1     Pending             0          0s     <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     Pending             0          0s     <none>          <none>   <none>           <none>
statefulset-test-0                    0/1     ContainerCreating   0          0s     <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     Pending             0          0s     <none>          node-1   <none>           <none>
statefulset-test-1                    0/1     ContainerCreating   0          0s     <none>          node-1   <none>           <none>
statefulset-test-2                    0/1     ContainerCreating   0          0s     <none>          node-1   <none>           <none>
statefulset-test-1                    1/1     Running             0          2s     192.168.1.248   node-1   <none>           <none>
statefulset-test-0                    1/1     Running             0          2s     192.168.1.249   node-1   <none>           <none>
statefulset-test-2                    1/1     Running             0          2s     192.168.1.250   node-1   <none>           <none>

statefulset-test-2                    1/1     Terminating         0          83s    192.168.1.250   node-1   <none>           <none>
statefulset-test-1                    1/1     Terminating         0          83s    192.168.1.248   node-1   <none>           <none>
statefulset-test-0                    1/1     Terminating         0          83s    192.168.1.249   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          84s    192.168.1.248   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          84s    192.168.1.249   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          84s    192.168.1.250   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          90s    192.168.1.248   node-1   <none>           <none>
statefulset-test-1                    0/1     Terminating         0          90s    192.168.1.248   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          90s    192.168.1.250   node-1   <none>           <none>
statefulset-test-2                    0/1     Terminating         0          90s    192.168.1.250   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          90s    192.168.1.249   node-1   <none>           <none>
statefulset-test-0                    0/1     Terminating         0          90s    192.168.1.249   node-1   <none>           <none>
```

#### 19.为啥要用DaemonSet？

**To Be Continue ~**

#### 参考文档

>`https://kubernetes.io/zh/docs/tutorials/stateful-application/basic-stateful-set/`

>`https://developer.aliyun.com/lesson_1651_18371#_18371`

>`https://kubernetes.io/zh/docs/tutorials/stateful-application/zookeeper/`

>`https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/`
