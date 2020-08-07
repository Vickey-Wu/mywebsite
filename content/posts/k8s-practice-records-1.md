---
title: "k8s实践记录（一）"
date: 2020-07-01T03:10:06Z
description:  "k8s实践记录（一）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/E89AFE6CBA8E4D1CB52E1F17DBEC703E?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

#### 1. 一个节点挂了，其中的pod是否会自动迁移到正常节点？

此时有3个nginx在跑，一个在node-1,一个在node-2，将node-2关机
```
[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS    RESTARTS   AGE     IP            NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-4m4vf   1/1     Running   0          8m57s   192.168.1.8   node-1   <none>           <none>
my-nginx-f97c96f6d-7tj75   1/1     Running   0          8m57s   192.168.2.2   node-2   <none>           <none>
my-nginx-f97c96f6d-h7k5t   1/1     Running   0          9m14s   192.168.1.7   node-1   <none>           <none>
```

之后看到k8s在node-1自动创建了一个新的nginx来替代node-2的nginx
```
[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS    RESTARTS   AGE     IP            NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-4m4vf   1/1     Running   0          8m57s   192.168.1.8   node-1   <none>           <none>
my-nginx-f97c96f6d-7tj75   1/1     Running   0          8m57s   192.168.2.2   node-2   <none>           <none>
my-nginx-f97c96f6d-h7k5t   1/1     Running   0          9m14s   192.168.1.7   node-1   <none>           <none>
my-nginx-f97c96f6d-7tj75   1/1     Running   0          10m     192.168.2.2   node-2   <none>           <none>
my-nginx-f97c96f6d-7tj75   1/1     Terminating   0          15m     192.168.2.2   node-2   <none>           <none>
my-nginx-f97c96f6d-smpgq   0/1     Pending       0          0s      <none>        <none>   <none>           <none>
my-nginx-f97c96f6d-smpgq   0/1     Pending       0          0s      <none>        node-1   <none>           <none>
my-nginx-f97c96f6d-smpgq   0/1     ContainerCreating   0          0s      <none>        node-1   <none>           <none>
my-nginx-f97c96f6d-smpgq   1/1     Running             0          12s     192.168.1.9   node-1   <none>           <none>
```

#### 2. 一个节点打上了taint，设为NoSchedule会咋样？

未打上`taint`之前，`node`节点值默认为`none`，注意：`master`节点默认是`Taints:             node-role.kubernetes.io/master:NoSchedule`

```
[root@master-1 ~]# kubectl describe nodes node-1
...
Taints:             <none>

[root@master-1 ~]# kubectl taint node node-1 test=testnode:NoSchedule
node/node-1 tainted

[root@master-1 ~]# kubectl describe nodes node-1
...
Taints:             test=testnode:NoSchedule

[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS    RESTARTS   AGE     IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-fbcwv   1/1     Running   0          2m48s   192.168.2.6    node-2   <none>           <none>
my-nginx-f97c96f6d-nb9pq   1/1     Running   0          2m48s   192.168.1.15   node-1   <none>           <none>
my-nginx-f97c96f6d-xwqvt   1/1     Running   0          2m48s   192.168.1.14   node-1   <none>           <none>
```

`node-1`打上`Taints`为`test=testnode:NoSchedule`，发现原有已经运行在`node-1`的`pod`并未受影响，继续运行在`node-1`，给`nginx`扩容试试

```
[root@master-1 ~]# kubectl scale deployment my-nginx --replicas=5
deployment.apps/my-nginx scaled

[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS    RESTARTS   AGE     IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-fbcwv   1/1     Running   0          2m48s   192.168.2.6    node-2   <none>           <none>
my-nginx-f97c96f6d-nb9pq   1/1     Running   0          2m48s   192.168.1.15   node-1   <none>           <none>
my-nginx-f97c96f6d-xwqvt   1/1     Running   0          2m48s   192.168.1.14   node-1   <none>           <none>
my-nginx-f97c96f6d-pf4s2   0/1     Pending   0          0s      <none>         <none>   <none>           <none>
my-nginx-f97c96f6d-pf4s2   0/1     Pending   0          0s      <none>         node-2   <none>           <none>
my-nginx-f97c96f6d-wnxrf   0/1     Pending   0          0s      <none>         <none>   <none>           <none>
my-nginx-f97c96f6d-wnxrf   0/1     Pending   0          0s      <none>         node-2   <none>           <none>
my-nginx-f97c96f6d-pf4s2   0/1     ContainerCreating   0          0s      <none>         node-2   <none>           <none>
my-nginx-f97c96f6d-wnxrf   0/1     ContainerCreating   0          0s      <none>         node-2   <none>           <none>
my-nginx-f97c96f6d-pf4s2   1/1     Running             0          6s      192.168.2.7    node-2   <none>           <none>
my-nginx-f97c96f6d-wnxrf   1/1     Running             0          8s      192.168.2.8    node-2   <none>           <none>
```

扩容后发现新增的`nginx`都调度到`node-2`上了，然后将所有`nginx`都干掉重新调度看看，发现真的都不会调度到`node-1`上了。

```
[root@master-1 ~]# kubectl delete -f my-nginx.yaml 
deployment.apps "my-nginx" deleted
[root@master-1 ~]# kubectl apply -f my-nginx.yaml 
deployment.apps/my-nginx created

[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS              RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-mpfvw   0/1     ContainerCreating   0          4s    <none>   node-2   <none>           <none>
my-nginx-f97c96f6d-tpw7m   0/1     ContainerCreating   0          4s    <none>   node-2   <none>           <none>
my-nginx-f97c96f6d-zbjcx   0/1     ContainerCreating   0          4s    <none>   node-2   <none>           <none>
my-nginx-f97c96f6d-zbjcx   1/1     Running             0          5s    192.168.2.9   node-2   <none>           <none>
my-nginx-f97c96f6d-tpw7m   1/1     Running             0          9s    192.168.2.10   node-2   <none>           <none>
my-nginx-f97c96f6d-mpfvw   1/1     Running             0          11s   192.168.2.11   node-2   <none>           <none>
```

`taint, cordon`功能类似，会将node设为不可调度，但已在node上的pod不受影响；

`drain`会将node设为不可调度， 会将node上所有已有pod驱逐到另一个可用node上(`24s`的那些就是被驱逐过来的)；

`cordon, drain`会将node设置为
```
Taints:             node.kubernetes.io/unschedulable:NoSchedule
Unschedulable:      true
```

```
[root@master-1 yamlfiles]# kubectl get pod  -o wide
NAME                    READY   STATUS    RESTARTS   AGE    IP             NODE     NOMINATED NODE   READINESS GATES
my-ng-7ff4f97cf-djzt2   1/1     Running   0          81m    192.168.2.44   node-2   <none>           <none>
my-ng-7ff4f97cf-mdmtt   1/1     Running   0          81m    192.168.2.43   node-2   <none>           <none>
my-ng-7ff4f97cf-q4n6w   1/1     Running   0          83m    192.168.1.53   node-1   <none>           <none>
my-ng-7ff4f97cf-qlhcg   1/1     Running   0          78m    192.168.1.54   node-1   <none>           <none>

[root@master-1 yamlfiles]# kubectl drain node-2 --ignore-daemonsets
node/node-2 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-flannel-ds-amd64-zwdcc, kube-system/kube-proxy-mcczt
evicting pod "my-ng-7ff4f97cf-mdmtt"
evicting pod "my-ng-7ff4f97cf-djzt2"
pod/my-ng-7ff4f97cf-djzt2 evicted
pod/my-ng-7ff4f97cf-mdmtt evicted
node/node-2 evicted

[root@master-1 yamlfiles]# kubectl get pod -o wide
NAME                    READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-ng-7ff4f97cf-6c7wm   1/1     Running   0          24s   192.168.1.60   node-1   <none>           <none>
my-ng-7ff4f97cf-plxj5   1/1     Running   0          24s   192.168.1.59   node-1   <none>           <none>
my-ng-7ff4f97cf-q4n6w   1/1     Running   0          89m   192.168.1.53   node-1   <none>           <none>
my-ng-7ff4f97cf-qlhcg   1/1     Running   0          85m   192.168.1.54   node-1   <none>           <none>
```


#### 3. 我一定要我的`pod`能调度到有这个`NoSchedule`的该咋搞？

1. 这时我们可以在`nginx`的`yaml`文件里的`pod`模板`template`的`spec`下面加多个容忍度`tolerations`，这样就可以了。

```
[root@master-1 ~]# cat my-nginx.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: my-nginx
  name: my-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: my-nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
      tolerations:
      - key: 'test'
        operator: "Equal"
        value: "testnode"
        effect: "NoSchedule"
status: {}
```
```
[root@master-1 ~]# kubectl get pod -o wide -w
NAME                        READY   STATUS              RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-548d8776b7-prsvr   0/1     ContainerCreating   0          4s    <none>         node-2   <none>           <none>
my-nginx-548d8776b7-qkthl   0/1     ContainerCreating   0          4s    <none>         node-2   <none>           <none>
my-nginx-548d8776b7-t47v2   1/1     Running             0          4s    192.168.1.19   node-1   <none>           <none>
my-nginx-548d8776b7-prsvr   1/1     Running             0          5s    192.168.2.17   node-2   <none>           <none>
my-nginx-548d8776b7-qkthl   1/1     Running             0          10s   192.168.2.18   node-2   <none>           <none>
```

2. 移除所有节点中加了这个`taint`，其实就是在这个值后面加多一个`-`，这样`node-1`就又可以调度了

```
[root@master-1 ~]# kubectl taint node node-1 test=testnode:NoSchedule-
node/node-1 untainted

[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS              RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-8jc7r   0/1     ContainerCreating   0          7s    <none>         node-1   <none>           <none>
my-nginx-f97c96f6d-fff2b   0/1     ContainerCreating   0          7s    <none>         node-1   <none>           <none>
my-nginx-f97c96f6d-sggbd   1/1     Running             0          7s    192.168.2.14   node-2   <none>           <none>
my-nginx-f97c96f6d-fff2b   1/1     Running             0          9s    192.168.1.16   node-1   <none>           <none>
my-nginx-f97c96f6d-8jc7r   1/1     Running             0          10s   192.168.1.17   node-1   <none>           <none>
```

#### 4. 我希望我的pod只调度到指定node上咋搞？

##### 方法一：nodeSeletor

将node打上标签`testlabel=t1`，或者直接选择node默认label（删除已有标签`kubectl label nodes node-1 testlabel-`）

```
[root@master-1 yamlfiles]# kubectl label nodes node-1 testlabel=t1
node/node-1 labeled

[root@master-1 yamlfiles]# kubectl get nodes node-1 --show-labels 
NAME     STATUS   ROLES    AGE     VERSION   LABELS
node-1   Ready    <none>   4h32m   v1.16.9   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node-1,kubernetes.io/os=linux,testlabel=t1
```

在yaml文件里增加`nodeSelector`，选择刚才创建的标签`testlabel: t1`

```
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: my-nginx
  name: my-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: my-nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
      nodeSelector:
        testlabel: t1
        #kubernetes.io/hostname: node-2
        #beta.kubernetes.io/os: linux
```

可以看到3个pod都只调度到`node-1`

```
[root@master-1 yamlfiles]# kubectl apply -f my-nginx.yaml 
deployment.apps/my-nginx created
[root@master-1 yamlfiles]# kubectl get pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-75dd5c585b-mk5rk   1/1     Running   0          56s   192.168.1.62   node-1   <none>           <none>
my-nginx-75dd5c585b-wbbb8   1/1     Running   0          56s   192.168.1.63   node-1   <none>           <none>
my-nginx-75dd5c585b-x4j4s   1/1     Running   0          56s   192.168.1.61   node-1   <none>           <none>
```

然后我们将yaml文件里的`nodeSelector`改为node自带的`kubernetes.io/hostname: node-2`，同时注释原来的`testlabel: t1`，再apply，发现原来全部在node-1的pod都被调度到了新的node-2

```
[root@master-1 ~]# kubectl get pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-75dd5c585b-7g6ph   1/1     Running   0          36s   192.168.1.65   node-1   <none>           <none>
my-nginx-75dd5c585b-t6h2t   1/1     Running   0          39s   192.168.1.64   node-1   <none>           <none>
my-nginx-75dd5c585b-v8rr5   1/1     Running   0          30s   192.168.1.66   node-1   <none>           <none>
[root@master-1 ~]# kubectl get pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-7f84bb67c6-hpmww   1/1     Running   0          29s   192.168.2.50   node-2   <none>           <none>
my-nginx-7f84bb67c6-lmrq7   1/1     Running   0          33s   192.168.2.49   node-2   <none>           <none>
my-nginx-7f84bb67c6-z8qsx   1/1     Running   0          24s   192.168.2.51   node-2   <none>           <none>
```

如果上面没有注释掉`testlabel: t1`，则需要**同时满足2个label**的node才可以调度成功，但一个label在node-1，一个在node-2，所以调度就会一直处于pending状态，直到有满足lable条件的node出现。当然，如果node-1和node-2具有相同的label，如`beta.kubernetes.io/os: linux`，则都会调度成功。

```
[root@master-1 yamlfiles]# kubectl get pod  -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-5bff69c4f7-xcchj   0/1     Pending   0          2m33s   <none>         <none>   <none>           <none>

[root@master-1 yamlfiles]# kubectl describe pod my-nginx-5bff69c4f7-xcchj 
...
Warning  FailedScheduling  <unknown>  default-scheduler  0/3 nodes are available: 3 node(s) didn't match node selector.
...
```

##### 方法二：nodeAffinity

由方法一例子可见，`nodeSelector`的约束条件只能同时满足多个label的node才能成功调度，而**不能**满足多个label中的一个就成功调度。而️`affinity`中的`nodeAffinity`跟`nodeSelector`功能类似，也是用于调度pod到指定node，但它增强了表达约束的条件，它可以满足我们的需求：满足多个label中的一个就成功调度。

在yaml文件里写明约束条件为：键为`kubernetes.io/hostname`，值包含`node-1`或`node-2`，满足这个条件即可成功调度pod

```
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: my-nginx
  name: my-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: my-nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - node-1
                - node-2
```

由下可见，node-1和node-2均成功调度了pod

```
[root@master-1 yamlfiles]# kubectl apply -f  my-nginx.yaml 
deployment.apps/my-nginx created
[root@master-1 yamlfiles]# kubectl get pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-79f78cf6c6-5fbb6   1/1     Running   0          67s   192.168.1.71   node-1   <none>           <none>
my-nginx-79f78cf6c6-kpfzg   1/1     Running   0          67s   192.168.1.72   node-1   <none>           <none>
my-nginx-79f78cf6c6-pr5zj   1/1     Running   0          67s   192.168.2.66   node-2   <none>           <none>
```

如果注释其中一个条件，则效果就跟`nodeSelector`一致了，这里不再赘述。接着看如何选择满足多个条件中最优的一个node。比如我要优先从满足条件的node中选择cpu为2的节点，我给node-1加了个`cpunums=2`，在yaml文件增加以下条件

```
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: cupnums
                operator: In
                values:
                - "2"
```

但事实上这个`preferredDuringSchedulingIgnoredDuringExecution`条件只是尽可能多调度到满足此条件的node上，并不能100%调度到此node上，所以`preferredDuringSchedulingIgnoredDuringExecution`称为“软”规则，不一定调度到满足此规则的node上；`requiredDuringSchedulingIgnoredDuringExecution`称为“硬”规则，一定会调度到满足此规则的node上。

```
[root@master-1 ~]# kubectl get pod -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
my-nginx-8d97ff5d6-4zh7f   1/1     Running   0          38s   192.168.2.70   node-2   <none>           <none>
my-nginx-8d97ff5d6-bq5cc   1/1     Running   0          35s   192.168.1.74   node-1   <none>           <none>
my-nginx-8d97ff5d6-jmhbs   1/1     Running   0          41s   192.168.1.73   node-1   <none>           <none>
```

**注意点**：

1.如果你同时指定了 `nodeSelector` 和 `nodeAffinity`，两者必须都要满足，才能将 pod 调度到候选节点上。

2.如果你指定了多个与 `nodeAffinity` 类型关联的 `nodeSelectorTerms`，则如果其中一个 `nodeSelectorTerms` 满足的话，pod将可以调度到节点上。

3.如果你指定了多个与 `nodeSelectorTerms` 关联的 `matchExpressions`，则只有当所有 `matchExpressions` 满足的话，pod 才会可以调度到节点上

4.`preferredDuringSchedulingIgnoredDuringExecution` 中的 `weight` 字段值的范围是 1-100，总分最高的节点是最优选的

**更多查看**：
>`https://kubernetes.io/zh/docs/concepts/configuration/assign-pod-node/`

#### 5. 那我希望我的pod只跟具有某些特征的pod在同一个node上该咋搞？

首先我在node-1加上了label `cpunums=2`和`failure-domain.beta.kubernetes.io/zone=cn-shenzhen`；在node-2加上了label `failure-domain.beta.kubernetes.io/zone=cn-hangzhou`

**第一类pod**，带有label `app: my-nginx`，根据`nodeAffinity`，它可以部署到节点node-1和node-2，优先部署多个实例到带有label `cpunums=2`的节点node-1

```
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: my-nginx
  name: my-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: my-nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        resources: {}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - node-1
                - node-2
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: cupnums
                operator: In
                values:
                - "2"
```

**第二类pod**，我希望它跟第一类pod部署到同一个节点上，这里`podAffinity`会**选择**带有`topologyKey`为`failure-domain.beta.kubernetes.io/zone`的节点，再从这些节点筛选出已经部署带有label`app=my-nginx`的pod的节点；然后再从上一步中筛选的节点用`podAntiAffinity`过滤掉不符合的节点，这里不符合的节点为部署有label为`app=test-pod-affinity`的pod所在的node，因为我这里只有两个node，但我这里要部署3个带有`app=test-pod-affinity`的pod，所以当两个node都部署了带有`app=test-pod-affinity`的pod之后，第3个带有`app=test-pod-affinity`的pod将一直处于pending状态。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: test-pod-affinity
  name: test-pod-affinity
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-pod-affinity
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: test-pod-affinity
    spec:
      containers:
      - image: nginx
        name: test-pod-affinity
        resources: {}
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - my-nginx
            topologyKey: failure-domain.beta.kubernetes.io/zone
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - test-pod-affinity
            topologyKey: failure-domain.beta.kubernetes.io/zone
```

结果如我们预料的一样：第二类pod调度到了带有label为`app=my-nginx`的pod所在都节点，但根据`podAntiAffinity`要求，只会有2个第二类pod调度成功，因为我这里只有两个node，但我这里要部署3个带有`app=test-pod-affinity`的pod，所以当两个node都部署了带有`app=test-pod-affinity`的pod之后，第3个带有`app=test-pod-affinity`的pod将一直处于`pending`状态。

```
[root@master-1 yamlfiles]# kubectl get pod -o wide
NAME                                 READY   STATUS    RESTARTS   AGE     IP              NODE     NOMINATED NODE   READINESS GATES
my-nginx-8d97ff5d6-7xvkr             1/1     Running   0          2m47s   192.168.2.124   node-2   <none>           <none>
my-nginx-8d97ff5d6-8zggl             1/1     Running   0          2m47s   192.168.1.144   node-1   <none>           <none>
my-nginx-8d97ff5d6-q8g2f             1/1     Running   0          2m47s   192.168.1.143   node-1   <none>           <none>
test-pod-affinity-65c9884f5c-9hs6r   1/1     Running   0          18s     192.168.2.125   node-2   <none>           <none>
test-pod-affinity-65c9884f5c-b2dqx   0/1     Pending   0          18s     <none>          <none>   <none>           <none>
test-pod-affinity-65c9884f5c-tpppz   1/1     Running   0          18s     192.168.1.145   node-1   <none>           <none>
```


#### 6.如何持久化pod数据?

**To Be Continue !**
