---
title: "k8s实践记录（三）"
date: 2020-08-01T03:10:06Z
description:  "k8s实践记录（三）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/5B378AB17AA1468EB4CE978A288CE130?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

#### 11.如何挂载配置文件到pod？

配置文件一般用`configmap`类型挂载，需要先创建一个配置文件的configmap，然后在pod中引用这个configmap的名字即可。

```
[root@master-1 yamlfiles]# cat test-configmap/ui.properties 
color.good=purple
color.bad=yellow
allow.textmode=true
how.nice.to.look=fairlyNice

[root@master-1 yamlfiles]# cat test-configmap/game.properties 
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
secret.code.lives=30
```

`data`部分就是配置文件`game.properties`的具体数据，一个configmap可以同时存放多个配置文件

```
[root@master-1 yamlfiles]# kubectl  create configmap test-configmap --from-file test-configmap/
configmap/test-configmap created
[root@master-1 yamlfiles]# kubectl  get configmaps -o yaml
apiVersion: v1
items:
- apiVersion: v1
  data:
    game.properties: |-
      enemies=aliens
      lives=3
      enemies.cheat=true
      enemies.cheat.level=noGoodRotten
      secret.code.passphrase=UUDDLRLRBABAS
      secret.code.allowed=true
      secret.code.lives=30
    ui.properties: |
      color.good=purple
      color.bad=yellow
      allow.textmode=true
      how.nice.to.look=fairlyNice
  kind: ConfigMap
  metadata:
    creationTimestamp: "2020-07-13T02:27:36Z"
    name: test-configmap
    namespace: default
    resourceVersion: "426653"
    selfLink: /api/v1/namespaces/default/configmaps/test-configmap
    uid: 233933da-905e-480d-beef-a00ee19fb190
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
```

在pod中引用这个configmap

```
[root@master-1 yamlfiles]# cat test-configmap.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-configmap-pod
  labels:
    app: test-configmap-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-configmap-pod
  template:
    metadata:
      labels:
        app: test-configmap-pod
    spec:
      containers:
      - name: test-configmap-pod
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /tmp/nginx/testconfigmap
          name: test-configmap
      - name: test-configmap-pod-share
        image: redis
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /tmp/redis/testconfigmap
          #subPath: test-configmap-subpath
          name: test-configmap
      volumes:
      - name: test-configmap
        configMap:
          name: test-configmap

[root@master-1 yamlfiles]# kubectl  apply -f test-configmap.yaml 
deployment.apps/test-configmap-pod created

[root@master-1 yamlfiles]# kubectl get pod
NAME                                 READY   STATUS              RESTARTS   AGE
test-configmap-pod-7f448b6fc-k55w2   2/2     Running             0          19s
```

进入容器，查看到两个文件的确挂载进去了

```
[root@master-1 yamlfiles]# kubectl  exec -it test-configmap-pod-7f448b6fc-k55w2 /bin/bash
Defaulting container name to test-configmap-pod.
Use 'kubectl describe pod/test-configmap-pod-7f448b6fc-k55w2 -n default' to see all of the containers in this pod.

root@test-configmap-pod-7f448b6fc-k55w2:/# ls /tmp/nginx/testconfigmap/
game.properties  ui.properties
root@test-configmap-pod-7f448b6fc-k55w2:/# cat /tmp/nginx/testconfigmap/game.properties 
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
```

需要注意的是，不能将configmap挂载到pod的子目录，即不能使用`subPath`，不然配置文件就挂载不进去。将`subPath`注释去掉，重新创建pod，进入容器发现的确没有挂载进去，而没有使用`subPath`的容器就挂载进去了。

```
[root@master-1 yamlfiles]# kubectl  apply -f  test-configmap.yaml 
deployment.apps/test-configmap-pod configured

[root@master-1 yamlfiles]# kubectl  exec -it test-configmap-pod-56545959fb-lsrt2 /bin/bash
Defaulting container name to test-configmap-pod.
Use 'kubectl describe pod/test-configmap-pod-56545959fb-lsrt2 -n default' to see all of the containers in this pod.
root@test-configmap-pod-56545959fb-lsrt2:/# ls /tmp/nginx/testconfigmap/
root@test-configmap-pod-56545959fb-lsrt2:/# exit

[root@master-1 yamlfiles]# kubectl  exec -it test-configmap-pod-56545959fb-lsrt2 -c test-configmap-pod-share /bin/bash
root@test-configmap-pod-56545959fb-lsrt2:/data# ls /tmp/redis/testconfigmap/
root@test-configmap-pod-56545959fb-lsrt2:/data# ls /tmp/redis/testconfigmap/
game.properties  test-configmap-subpath  ui.properties
```

configmap还可以**以env方式挂载**到pod

```
        #volumeMounts:
        #- mountPath: /tmp/redis/testconfigmap
        #  name: test-configmap
        env:
          - name: CONFIGMAP_ENV
            valueFrom:
              configMapKeyRef:
                name: test-configmap
                key: game.properties
```
将`volumeMounts`方式改为`env`，`apply`后进入对应容器即可查看变量，但只能读取到文件中的一行。
```
[root@master-1 yamlfiles]# kubectl  exec -it test-configmap-pod-674dc6685c-v48jw -c  test-configmap-pod-share /bin/bash
root@test-configmap-pod-674dc6685c-v48jw:/data# env|grep -i env
CONFIGMAP_ENV=enemies=aliens
_=/usr/bin/env
```

**configmap注意点**：

参考：`https://developer.aliyun.com/lesson_1651_18356?spm=5176.10731542.0.0.3ad220beJOP4PG#_18356`

> - ConfigMap 文件的大小。虽然说 ConfigMap 文件没有大小限制，但是在 ETCD 里面，数据的写入是有大小限制的，现在是限制在 1MB 以内；

> - 第二个注意点是 pod 引入 ConfigMap 的时候，必须是相同的 Namespace 中的 ConfigMap，我这里测试是默认都是 default，所以不会报错；

> - 第三个是 pod 引用的 ConfigMap。假如这个 ConfigMap 不存在，那么这个 pod 是无法创建成功的，其实这也表示在创建 pod 前，必须先把要引用的 ConfigMap 创建好；

> - 第四点就是使用 envFrom 的方式。把 ConfigMap 里面所有的信息导入成环境变量时，如果 ConfigMap 里有些 key 是无效的，比如 key 的名字里面带有数字，那么这个环境变量其实是不会注入容器的，它会被忽略。但是这个 pod 本身是可以创建的。这个和第三点是不一样的方式，是 ConfigMap 文件存在基础上，整体导入成环境变量的一种形式；

> - 最后一点是：什么样的 pod 才能使用 ConfigMap？这里只有通过 K8s api 创建的 pod 才能使用 ConfigMap，比如说通过用命令行 kubectl 来创建的 pod，肯定是可以使用 ConfigMap 的，但其他方式创建的 pod，比如说 kubelet 通过 manifest 创建的 static pod，它是不能使用 ConfigMap 的。

#### 12.在容器中如何引用pod的label等元数据？

```
[root@master-1 yamlfiles]# cat test-downwardapi.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-downwardapi
  labels:
    app: test-downwardapi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-downwardapi
  template:
    metadata:
      labels:
        zone: cn-shenzhen
        app: test-downwardapi
      annotations:
        company: vickey-wu.com
        author: vickey-wu
    spec:
      containers:
      - name: test-downwardapi
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /tmp/nginx/testdownwardapi
          #subPath: testdownwardapi-subpath
          name: test-downwardapi
      - name: test-downwardapi-share
        image: redis
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /tmp/redis/testdownwardapi
          name: test-downwardapi
      volumes:
        - name: test-downwardapi
          downwardAPI:
            items:
              - path: 'pod-labels'
                fieldRef:
                  fieldPath: metadata.labels
              - path: 'pod-annotations'
                fieldRef:
                  fieldPath: metadata.annotations
```

k8s通过挂载`downwardAPI`类型的卷来实现将**pod的元数据**（非deployment的元数据）存放到pod的容器的指定目录中。要注意的是，`downwardAPI`跟`configmap`一样不能挂载`subPath`，不然挂载失败。

```
[root@master-1 yamlfiles]# kubectl  apply -f test-downwardapi.yaml 
deployment.apps/test-downwardapi created
[root@master-1 yamlfiles]# kubectl  get pod
NAME                               READY   STATUS    RESTARTS   AGE
test-downwardapi-98d688c4d-86bds   2/2     Running   0          8s

[root@master-1 yamlfiles]# kubectl  exec -it test-downwardapi-98d688c4d-86bds /bin/bash
Defaulting container name to test-downwardapi.
Use 'kubectl describe pod/test-downwardapi-98d688c4d-86bds -n default' to see all of the containers in this pod.

root@test-downwardapi-98d688c4d-86bds:/# cat /tmp/nginx/testdownwardapi/pod-labels 
app="test-downwardapi"
pod-template-hash="98d688c4d"
zone="cn-shenzhen"

root@test-downwardapi-98d688c4d-86bds:/# cat /tmp/nginx/testdownwardapi/pod-annotations 
author="vickey-wu"
company="vickey-wu.com"
kubernetes.io/config.seen="2020-07-13T13:48:31.839008328+08:00"
kubernetes.io/config.source="api"
```

可以看到pod的`labels, annotations`分别被存放到文件`pod-labels, pod-annotations`，除了自己加的还有些k8s自动加的。

#### 13.如何挂载密码等敏感信息到pod？

**方法一**：使用`--from-file`创建`secret`，不需要提前加密，k8s创建时自动加密。

```
[root@master-1 yamlfiles]# mkdir test-secret
[root@master-1 yamlfiles]# echo 'admin' > test-secret/username.txt 
[root@master-1 yamlfiles]# echo '123123' > test-secret/passwd.txt 

[root@master-1 yamlfiles]# kubectl  create secret generic test-secret --from-file test-secret/
secret/test-secret created
```

查看`secret`发现已经是经过了`base64`加密的结果。测试加解密结果一致。

```
[root@master-1 yamlfiles]# kubectl  get secrets test-secret -o yaml
apiVersion: v1
data:
  passwd.txt: MTIzMTIz
  username.txt: YWRtaW4K
kind: Secret
metadata:
  creationTimestamp: "2020-07-13T08:11:53Z"
  name: test-secret
  namespace: default
  resourceVersion: "457050"
  selfLink: /api/v1/namespaces/default/secrets/test-secret
  uid: 5e48fc43-d2ab-4a8f-a21b-d6db9ea64955
type: Opaque


[root@master-1 yamlfiles]# echo -n 'admin'|base64       # 加密
YWRtaW4=
[root@master-1 yamlfiles]# echo -n 'MTIzMTIz'|base64 --decode        # 解密
123123
```

**方法二**：从yaml文件创建`secret`，需要提前使用`base64`加密，否则报错`v1.Secret.Data: base64Codec: invalid input`。

```
[root@master-1 yamlfiles]# cat test-secret.yaml 
apiVersion: v1
kind: Secret
metadata:
  name: test-secret-2
type: Opaque
data:
  #username: admin
  #password: 123123
  username: YWRtaW4=
  password: MTIzMTIz
#stringData:
#  username: root
#  password: '123456'
```

```
[root@master-1 yamlfiles]# kubectl  get secrets test-secret-2 -o yaml
apiVersion: v1
data:
  password: MTIzMTIz
  username: YWRtaW4=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"password":"MTIzMTIz","username":"YWRtaW4="},"kind":"Secret","metadata":{"annotations":{},"name":"test-secret-2","namespace":"default"},"type":"Opaque"}
  creationTimestamp: "2020-07-13T07:56:45Z"
  name: test-secret-2
  namespace: default
  resourceVersion: "455729"
  selfLink: /api/v1/namespaces/default/secrets/test-secret-2
  uid: 5977d545-b84e-4045-93ad-6d5e6342327c
type: Opaque
```

或者使用`stringData`字段，它可以不用提前加密，创建时自动加密。当`data`和`stringData`同时存在时，**优先使用`stringData`字段**的值。将前面的yaml文件的`stringData`取消注释，`kubectl apply`后发现账号密码都变为了`stringData`的值

```
[root@master-1 yamlfiles]# kubectl  apply -f test-secret.yaml 
secret/test-secret-2 configured

[root@master-1 yamlfiles]# kubectl  get secrets test-secret-2 -o yaml
apiVersion: v1
data:
  password: MTIzNDU2
  username: cm9vdA==
...


[root@master-1 yamlfiles]# echo -n 'cm9vdA=='|base64 --decode 
root
[root@master-1 yamlfiles]# echo -n 'MTIzNDU2'|base64 --decode 
123456
```

**进入正题，将secret挂载到pod**

```
[root@master-1 yamlfiles]# cat test-secret-pod-as-file.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-secret-pod
  labels:
    app: test-secret-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-secret-pod
  template:
    metadata:
      labels:
        app: test-secret-pod
    spec:
      containers:
      - name: test-secret-pod
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /tmp/nginx/testsecret
          #subPath: test-secret-subpath
          name: test-secret
          readOnly: true
      - name: test-secret-pod-share
        image: redis
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /tmp/redis/testsecret
          name: test-secret
          readOnly: true
      volumes:
      - name: test-secret
        secret:
          secretName: test-secret-2
          defaultMode: 0400             # default 0644
```

进入容器发现已挂载成功，权限也是设置的`0400`，需要注意的是，`secret, configmap, downwardAPI`都不支持挂载到`subPath`

```
[root@master-1 yamlfiles]# kubectl  get pod
NAME                               READY   STATUS    RESTARTS   AGE
test-secret-pod-5847c484d7-nwswp   2/2     Running   0          5s

[root@master-1 yamlfiles]# kubectl exec  -it test-secret-pod-5847c484d7-nwswp /bin/bash
Defaulting container name to test-secret-pod.
Use 'kubectl describe pod/test-secret-pod-5847c484d7-nwswp -n default' to see all of the containers in this pod.


root@test-secret-pod-5847c484d7-nwswp:/# cat /tmp/nginx/testsecret/username 
root
root@test-secret-pod-5847c484d7-nwswp:/# cat /tmp/nginx/testsecret/password 
123456


root@test-secret-pod-5847c484d7-nwswp:/data# ls -la /tmp/redis/testsecret/
lrwxrwxrwx. 1 root root  15 Jul 13 09:27 password -> ..data/password
lrwxrwxrwx. 1 root root  15 Jul 13 09:27 username -> ..data/username

root@test-secret-pod-5847c484d7-nwswp:/data# ls -al /tmp/redis/testsecret/..data/
-r--------. 1 root root   6 Jul 13 09:27 password
-r--------. 1 root root   4 Jul 13 09:27 username
```

前面是将secret作为文件挂载，下面实践下**将secret作为环境变量挂载到pod中的容器**

```
[root@master-1 yamlfiles]# cat test-secret-pod-as-env.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-secret-pod
  labels:
    app: test-secret-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-secret-pod
  template:
    metadata:
      labels:
        app: test-secret-pod
    spec:
      containers:
      - name: test-secret-pod
        image: nginx
        ports:
        - containerPort: 80
        env:
          - name: SECRET_USERNAME
            valueFrom:
              secretKeyRef:
                name: test-secret-2
                key: username
          - name: SECRET_PASSWORD
            valueFrom:
              secretKeyRef:
                name: test-secret-2
                key: password
```

进入容器，打印变量可以看到就是上面创建的`test-secret-2`账号密码`root, 123456`

```
[root@master-1 yamlfiles]# kubectl apply -f  test-secret-pod-as-env.yaml 
deployment.apps/test-secret-pod created

[root@master-1 yamlfiles]# kubectl get pod
NAME                               READY   STATUS        RESTARTS   AGE
test-secret-pod-56c8ffdb7c-qtf6d   1/1     Running       0          8s

[root@master-1 yamlfiles]# kubectl exec -it test-secret-pod-56c8ffdb7c-qtf6d /bin/bash
root@test-secret-pod-56c8ffdb7c-qtf6d:/# echo $SECRET_PASSWORD
123456
root@test-secret-pod-56c8ffdb7c-qtf6d:/# echo $SECRET_USERNAME
root
```

**secret注意点**：

参考：`https://developer.aliyun.com/lesson_1651_18356?spm=5176.10731542.0.0.3ad220beJOP4PG#_18356`

> - 第一个是 Secret 的文件大小限制。这个跟 ConfigMap 一样，也是 1MB；
 
> - 第二个是 Secret 采用了 base-64 编码，但是它跟明文也没有太大区别。所以说，如果有一些机密信息要用 Secret 来存储的话，还是要很慎重考虑。也就是说谁会来访问你这个集群，谁会来用你这个 Secret，还是要慎重考虑，因为它如果能够访问这个集群，就能拿到这个 Secret。如果是对 Secret 敏感信息要求很高，对加密这块有很强的需求，推荐可以使用 Kubernetes 和开源的 vault做一个解决方案，来解决敏感信息的加密和权限管理。

> - 第三个就是 Secret 读取的最佳实践，建议不要用 list/watch，如果用 list/watch 操作的话，会把 namespace 下的所有 Secret 全部拉取下来，这样其实暴露了更多的信息。推荐使用 GET 的方法，这样只获取你自己需要的那个 Secret。

#### 14.如何将各种挂载卷放到pod的同一个容器目录下

`projected`卷类型就是用来实现这个目的的。

```
[root@master-1 yamlfiles]# cat test-projected.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-projected-pod
  labels:
    app: test-projected-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-projected-pod
  template:
    metadata:
      labels:
        app: test-projected-pod
    spec:
      containers:
      - name: test-projected-pod
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /tmp/nginx/testprojected
          #subPath: test-projected-subpath
          name: test-projected
      - name: test-projected-pod-share
        image: redis
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /tmp/redis/testprojected
          name: test-projected
      volumes:
      - name: test-projected
        projected:
          sources:
          - configMap:
              name: test-configmap
              items:
                - key: game.properties
                  path: configmap-game
          - secret:
              name: test-secret
              items:
                - key: username.txt
                  path: secret-username.txt
          - secret:
              name: test-secret-2
              items:
                - key: username
                  path: secret-username-2
          - downwardAPI:
              items:
                - path: "labels"
                  fieldRef:
                    fieldPath: metadata.labels
                - path: "cpus"
                  resourceFieldRef:
                    containerName: test-projected-pod
                    resource: limits.cpu
```

```
[root@master-1 yamlfiles]# kubectl apply -f  test-projected.yaml 
deployment.apps/test-projected-pod created

[root@master-1 yamlfiles]# kubectl get pod 
NAME                                  READY   STATUS    RESTARTS   AGE
test-projected-pod-7dbff4f4bd-rnbh8   2/2     Running   0          18s
```

进入容器查看，`configmap, downwardAPI, 两个secret`类型的卷都挂载到`/tmp/nginx/testprojected/`目录下了，内容也OK。

```
[root@master-1 yamlfiles]# kubectl exec -it test-projected-pod-7dbff4f4bd-rnbh8 /bin/bash
Defaulting container name to test-projected-pod.
Use 'kubectl describe pod/test-projected-pod-7dbff4f4bd-rnbh8 -n default' to see all of the containers in this pod.

root@test-projected-pod-7dbff4f4bd-rnbh8:/# ls /tmp/nginx/testprojected/
configmap-game	cpus  labels  secret-username-2  secret-username.txt

root@test-projected-pod-7dbff4f4bd-rnbh8:/# cat /tmp/nginx/testprojected/configmap-game 
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
secret.code.lives=30

root@test-projected-pod-7dbff4f4bd-rnbh8:/# cat /tmp/nginx/testprojected/labels         
app="test-projected-pod"
pod-template-hash="7dbff4f4bd"

root@test-projected-pod-7dbff4f4bd-rnbh8:/# cat /tmp/nginx/testprojected/cpus 
2

root@test-projected-pod-7dbff4f4bd-rnbh8:/# cat /tmp/nginx/testprojected/secret-username.txt 
admin

root@test-projected-pod-7dbff4f4bd-rnbh8:/# cat /tmp/nginx/testprojected/secret-username-2   
root
```

#### 15 如何对容器使用资源做限制？

```
    spec:
      containers:
      - image: nginx
        #resources: {}
        resources: 
          requests:
            memory: "64Mi"
            cpu: "250m"
            ephemeral-storage: "2Gi"
          limits:
            memory: "64Mi"
            cpu: "250m"
            ephemeral-storage: "2Gi"
```

对容器使用资源做限制的字段：`requests`和`limits`。根据这两个字段对 pod 的服务质量进行一个分类，分别是 Guaranteed、Burstable 和 BestEffort。如果集群资源不够，将按照先去除 BestEffort，再去除 Burstable 的一个顺序来驱逐 pod 的。

> - Guaranteed ：pod 里面每个容器都必须有内存和 CPU 的 request 以及 limit 的一个声明，且 request 和 limit 必须是一样的，这就是 Guaranteed；

> - Burstable：Burstable 至少有一个容器存在内存和 CPU 的一个 request；

> - BestEffort：只要不是 Guaranteed 和 Burstable，那就是 BestEffort。

#### 16 如何对pod做权限限制？

**To Be Continue ~**
