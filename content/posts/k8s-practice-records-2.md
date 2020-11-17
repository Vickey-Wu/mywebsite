---
title: "k8s实践记录（二）"
date: 2020-07-10T03:10:06Z
description:  "k8s实践记录（二）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/58283B0DC083466B845FA919C7A60AC5?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

#### 6.如何使用emptydir共享pod中containers间的数据?

在实践持久化pod数据前，先了解下pod中容器间数据共享的方式

```
[root@master-1 yamlfiles]# cat test-emptydir.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-emptydir
  labels:
    app: test-emptydir
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-emptydir
  template:
    metadata:
      labels:
        app: test-emptydir
    spec:
      containers:
      - name: test-emptydir
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /tmp/nginx/testemptydir
          name: test-emptydir
      - name: test-emptydir-share
        image: redis
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /tmp/redis/testemptydir
          name: test-emptydir
      volumes:
      - name: test-emptydir
        emptyDir: {}
        #emptyDir:
        #  medium: Memory
        #  sizeLimit: 1Gi
```

这里会创建一个包含2个container的pod，分别是`test-emptydir`，`test-emptydir-share`，它们之间会共享同一个初始化为空的目录`test-emptydir`也就是2个容器各自挂载的目录`/tmp/nginx/testemptydir`和`/tmp/redis/testemptydir`。在其中一个容器的共享目录中写入内容，另一个容器就可以看到相同的内容。即使容器崩溃了(被误删，停止，k8s会自动重新创建容器)，共享目录的数据还是在的，但是如果pod被使用kubectl命令删除了，那数据也就删除了。

```
[root@master-1 yamlfiles]# kubectl apply -f test-emptydir.yaml 
deployment.apps/test-emptydir created

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-emptydir-66d9df598-p7mc5   2/2     Running   0          18s   192.168.2.144   node-2   <none>           <none>

[root@master-1 yamlfiles]# kubectl  exec -it test-emptydir-66d9df598-p7mc5 /bin/bash
Defaulting container name to test-emptydir.
Use 'kubectl describe pod/test-emptydir-66d9df598-p7mc5 -n default' to see all of the containers in this pod.
root@test-emptydir-66d9df598-p7mc5:/# cd /tmp/nginx/testemptydir/
root@test-emptydir-66d9df598-p7mc5:/tmp/nginx/testemptydir# ls
root@test-emptydir-66d9df598-p7mc5:/tmp/nginx/testemptydir# echo "test emptydir">test.txt
root@test-emptydir-66d9df598-p7mc5:/tmp/nginx/testemptydir# cat test.txt 
test emptydir

[root@master-1 yamlfiles]# kubectl  exec -it test-emptydir-66d9df598-p7mc5 -c test-emptydir-share /bin/bash
root@test-emptydir-66d9df598-p7mc5:/data# cat /tmp/redis/testemptydir/test.txt 
test emptydir
```

`emptydir`还可以挂载一个文件系统`tmpfs`，**k8s会在pod调度的节点创建一个文件系统挂载到pod的所有容器中，但在节点被重启时挂载的数据会被清除**，并且您所写入的所有文件都会计入容器的内存消耗，受容器内存限制约束

```
[root@master-1 yamlfiles]# cat test-emptydir.yaml 
...
        #emptyDir:
        #  medium: Memory
        #  sizeLimit: 1Gi
...

[root@master-1 yamlfiles]# kubectl get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP              NODE     NOMINATED NODE   READINESS GATES
test-emptydir-f94d7c7c7-57xsv   2/2     Running   0          6m10s   192.168.1.170   node-1   <none>           <none>
[root@master-1 yamlfiles]# kubectl exec -it test-emptydir-f94d7c7c7-57xsv /bin/bash
Defaulting container name to test-emptydir.
Use 'kubectl describe pod/test-emptydir-f94d7c7c7-57xsv -n default' to see all of the containers in this pod.
root@test-emptydir-f94d7c7c7-57xsv:/# df -h         # 创建的文件系统挂载到了pod的容器里
...
tmpfs                    910M     0  910M   0% /tmp/nginx/testemptydir

[root@node-1 ~]# df -h          # 在节点中创建的文件系统
...
/var/lib/kubelet/pods/52255ccd-af1e-4f0a-93da-c0d47a89b4af/volumes/kubernetes.io~empty-dir/test-emptydir
...
```

#### 7.如何使用hostPath持久化pod数据?

```
[root@master-1 yamlfiles]# cat test-hostpath.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-hostpath
  labels:
    app: test-hostpath
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-hostpath
  template:
    metadata:
      labels:
        app: test-hostpath
    spec:
      containers:
      - name: test-hostpath
        image: nginx
        volumeMounts:
        - mountPath: /var/local/testhostpath
          name: mountdir
        - mountPath: /var/local/testhostpath/test.txt
          name: mountfile
      volumes:
      - name: mountdir
        hostPath:
          # 确保文件所在目录成功创建。
          path: /tmp/testhostpath
          type: DirectoryOrCreate
      - name: mountfile
        hostPath:
          path: /tmp/testhostpath/test.txt
          type: FileOrCreate
```

可以看到有2个pod调度到了node-2，1个调度到了node-1，而且两个节点挂载的路径都没有预先创建文件`/tmp/testhostpath/test.txt`，调度成功后便会在调度到的节点动态创建目录及文件。

```
[root@master-1 yamlfiles]# kubectl  apply -f test-hostpath.yaml 
deployment.apps/test-hostpath created

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-hostpath-6c6c985d8-8lx95   1/1     Running   0          10s   192.168.2.135   node-2   <none>           <none>
test-hostpath-6c6c985d8-q6ckb   1/1     Running   0          10s   192.168.2.134   node-2   <none>           <none>
test-hostpath-6c6c985d8-wfv4s   1/1     Running   0          10s   192.168.1.155   node-1   <none>           <none>
```

ssh到node-2往挂载的文件写入内容，node-1不写入。

```
[root@node-2 ~]# echo "test hostpath"> /tmp/testhostpath/test.txt 
[root@node-2 ~]# cat /tmp/testhostpath/test.txt 
test hostpath
```

发现调度到node-2的pod挂载的文件已经有了写入的内容

```
[root@master-1 yamlfiles]# kubectl  exec -it test-hostpath-6c6c985d8-8lx95 /bin/bash
root@test-hostpath-6c6c985d8-8lx95:/# cat /var/local/testhostpath/test.txt 
test hostpath

[root@master-1 yamlfiles]# kubectl  exec -it test-hostpath-6c6c985d8-q6ckb /bin/bash
root@test-hostpath-6c6c985d8-q6ckb:/# cat /var/local/testhostpath/test.txt 
test hostpath
```

但调度到node-2的pod挂载的文件没有写入内容，所以由此可以看出，**`hostPath`挂载是在不同节点挂载了同一个名字的目录文件，但挂载的内容因节点不同而不同，也就是说`hostPath`挂载无法保证所有pod数据一致性**

```
[root@master-1 yamlfiles]# kubectl  exec -it test-hostpath-6c6c985d8-wfv4s /bin/bash
root@test-hostpath-6c6c985d8-wfv4s:/# cat /var/local/testhostpath/test.txt 
root@test-hostpath-6c6c985d8-wfv4s:/# 
```

将pod删除重建挂载的node-2数据依然存在，node-1的内容依然为空

```
[root@master-1 yamlfiles]# kubectl  delete -f  test-hostpath.yaml 
This command would delete k8s resources, please confirm again !!! [yes/no] yes
deployment.apps "test-hostpath" deleted
[root@master-1 yamlfiles]# kubectl apply -f  test-hostpath.yaml 
deployment.apps/test-hostpath created

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-hostpath-6c6c985d8-2bb9c   1/1     Running   0          17s   192.168.2.136   node-2   <none>           <none>
test-hostpath-6c6c985d8-hvhp2   1/1     Running   0          17s   192.168.1.157   node-1   <none>           <none>
test-hostpath-6c6c985d8-jdcx9   1/1     Running   0          17s   192.168.1.156   node-1   <none>           <none>

[root@master-1 yamlfiles]# kubectl  exec -ti test-hostpath-6c6c985d8-2bb9c /bin/bash
root@test-hostpath-6c6c985d8-2bb9c:/# cat /var/local/testhostpath/test.txt 
test hostpath

[root@master-1 yamlfiles]# kubectl  exec -ti test-hostpath-6c6c985d8-hvhp2 /bin/bash
root@test-hostpath-6c6c985d8-hvhp2:/# cat /var/local/testhostpath/test.txt 
root@test-hostpath-6c6c985d8-hvhp2:/# 
```

###### 实际应用

可以使用`hostPath`挂载`/var/run/docker.sock`路径来运行一个需要访问`Docker`引擎内部机制的容器。如在k8s用gitlab-ci来构建镜像用到的`gitlab-ci-multi-runner`就可以挂载`/var/run/docker.sock`来在容器内部访问k8s节点的docker了

```
[root@master-1 yamlfiles]# cat /etc/gitlab-runner/config.toml
...
      [[runners.kubernetes.volumes.host_path]]
        name = "docker"
        mount_path = "/var/run/docker.sock"
        read_only = true
...
```

#### 8.如何使用local持久化pod数据?

```
[root@k8s-master03 test]# cat test-localhost.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-local
  labels:
    app: test-local
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-local
  template:
    metadata:
      labels:
        app: test-local
    spec:
      containers:
      - name: test-local
        image: nginx
        volumeMounts:
        - mountPath: /var/local/testlocal
          name: local-mount
      volumes:
      - name: local-mount
        persistentVolumeClaim: 
          claimName: local-pvc

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /tmp/testlocal
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node-1

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: local-storage
  resources:
    requests:
      storage: 1Gi
```

创建之后发现一直在创建中，`kubectl describe`查看，发现没有找到挂载的目录，因为`local`卷只能用静态创建持久卷，尚不支持动态配置，**所以需要预习在挂载的节点对应目录下创建目录**，删除重新创建发现就正常运行了。

```
[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                         READY   STATUS              RESTARTS   AGE     IP       NODE     NOMINATED NODE   READINESS GATES
test-local-d97df679c-8gghv   0/1     ContainerCreating   0          9m25s   <none>   node-1   <none>           <none>
test-local-d97df679c-drx7x   0/1     ContainerCreating   0          9m25s   <none>   node-1   <none>           <none>
test-local-d97df679c-g99gx   0/1     ContainerCreating   0          9m25s   <none>   node-1   <none>           <none>

[root@master-1 yamlfiles]# kubectl  describe pod test-local-d97df679c-8gghv
...
  Warning  FailedMount       93s (x7 over 9m47s)  kubelet, node-1    MountVolume.NewMounter initialization failed for volume "local-pv" : path "/tmp/testlocal" does not exist
...

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-local-d97df679c-hqqbg   1/1     Running   0          13s   192.168.1.158   node-1   <none>           <none>
test-local-d97df679c-pbfv4   1/1     Running   0          13s   192.168.1.159   node-1   <none>           <none>
test-local-d97df679c-xq49h   1/1     Running   0          13s   192.168.1.160   node-1   <none>           <none>
```

当在预先创建的目录下写入测试内容`testlocal content`后就可以看到已经挂载上去了，再次删除重建数据依然存在（因为`persistentVolumeReclaimPolicy: Retain`），而且pod都只会调度到`node-1`，因为`nodeAffinity`跟`node-1`亲和。（`nodeAffinity`在[上篇](https://mp.weixin.qq.com/s/6D1LLLqxBkL0xEAqPvJddw)有提到例子）

```
[root@master-1 yamlfiles]# kubectl exec -it test-local-d97df679c-hqqbg /bin/bash
test-local-d97df679c-hqqbg:/# cat /var/local/testlocal/test.txt            # 测试内容已经挂载上去
testlocal content

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-local-d97df679c-lltfw   1/1     Running   0          17s   192.168.1.163   node-1   <none>           <none>
test-local-d97df679c-p784t   1/1     Running   0          17s   192.168.1.161   node-1   <none>           <none>
test-local-d97df679c-snwp7   1/1     Running   0          17s   192.168.1.162   node-1   <none>           <none>

[root@master-1 yamlfiles]# kubectl  exec -it test-local-d97df679c-lltfw /bin/bash
root@test-local-d97df679c-lltfw:/# cat /var/local/testlocal/test.txt 
test local
```

**由上面实践可知**

`local`卷只能用作静态创建的持久卷，尚不支持动态配置，**需要预习在挂载的节点对应目录下创建目录**；

只会将pod调度到指定有亲和性的节点，一旦这个节点挂了pod的服务就都挂了；

#### 9.如何使用nfs持久化pod数据

centos: 安装`rpcbind,nfs`，创建共享目录

```
[root@master-1 yamlfiles]# yum -y install nfs-utils rpcbind
Loaded plugins: fastestmirror
Determining fastest mirrors
 * base: mirrors.aliyun.com
 * extras: mirrors.163.com
 * updates: mirrors.163.com
...
Installed:
  nfs-utils.x86_64 1:1.3.0-0.66.el7             rpcbind.x86_64 0:0.2.0-49.el7                                                              
...
Complete!

[root@master-1 /]# chmod 755 /nfsshare/

[root@master-1 /]# echo "/nfsshare *(rw,sync,no_root_squash)" >> /etc/exports
[root@master-1 /]# cat /etc/exports
/nfsshare *(rw,sync,no_root_squash)
[root@master-1 /]# exportfs -rv
```

ubuntu

```
sudo apt-get install nfs-kernel-server  # 安装 NFS服务器端
sudo apt-get install nfs-common         # 安装 NFS客户端
```

启动`rpcbind, nfs`服务

```
[root@master-1 /]# systemctl start rpcbind.service 
[root@master-1 /]# systemctl enable rpcbind
[root@master-1 /]# systemctl status rpcbind
● rpcbind.service - RPC bind service
   Loaded: loaded (/usr/lib/systemd/system/rpcbind.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2020-07-09 14:55:36 CST; 26s ago
 Main PID: 76956 (rpcbind)
   CGroup: /system.slice/rpcbind.service
           └─76956 /sbin/rpcbind -w

Jul 09 14:55:36 master-1 systemd[1]: Starting RPC bind service...
Jul 09 14:55:36 master-1 systemd[1]: Started RPC bind service.


[root@master-1 /]# systemctl start nfs.service 
[root@master-1 /]# systemctl enable nfs
[root@master-1 /]# systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
  Drop-In: /run/systemd/generator/nfs-server.service.d
           └─order-with-mounts.conf
   Active: active (exited) since Thu 2020-07-09 14:56:43 CST; 31s ago
 Main PID: 77345 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

Jul 09 14:56:42 master-1 systemd[1]: Starting NFS server and services...
Jul 09 14:56:43 master-1 systemd[1]: Started NFS server and services.
```

使用`nfs`类型的`pv, pvc`文件

```
[root@master-1 yamlfiles]# cat test-nfs.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-nfs-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /nfsshare
    server: 192.168.229.130

---
#apiVersion: v1
#kind: PersistentVolumeClaim
#metadata:
#  name: test-nfs-pvc
#spec:
#  accessModes:
#  - ReadWriteMany
#  resources:
#    requests:
#      storage: 1Gi
```

未创建`test-nfs-pvc`前，创建的`test-nfs-pv`状态是`Available`的，创建了`test-nfs-pvc`后，因为`test-nfs-pv`的容量`1Gi`刚好符合`test-nfs-pvc`要求，所以就pv就跟pvc绑定了，他们的状态就都变为`Bound`了。

``` 
[root@master-1 yamlfiles]# kubectl  apply -f test-nfs.yaml 
persistentvolume/test-nfs-pv created
[root@master-1 yamlfiles]# kubectl  get pv
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
test-nfs-pv   1Gi        RWX            Recycle          Available                                   4s
[root@master-1 yamlfiles]# kubectl  apply -f  test-nfs.yaml 
persistentvolume/test-nfs-pv unchanged
persistentvolumeclaim/test-nfs-pvc created
[root@master-1 yamlfiles]# kubectl  get pv
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
test-nfs-pv   1Gi        RWX            Recycle          Bound    default/test-nfs-pvc                           8m57s
[root@master-1 yamlfiles]# kubectl  get pvc
NAME           STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-nfs-pvc   Bound    test-nfs-pv   1Gi        RWX                           14s
```

下面的`volumes`字段声明使用nfs类型的pvc `test-nfs-pvc`的子路径`nfspath`挂载到pod的`/usr/share/nginx/html`目录，创建后访问`http://192.168.229.130:30000/`就可以访问到`/nfsshare/nfspath/`目录下的文件了(需要先创建index.html文件，不然访问报错)。

```
[root@master-1 yamlfiles]# cat test-nfs.yaml 
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
      nodePort: 30000
  selector:
    app: test-nfs

---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: test-nfs
  name: test-nfs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-nfs
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: test-nfs
    spec:
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nfs-volume
          mountPath: /usr/share/nginx/html
          subPath: nfspath
        resources: {}
      volumes:
      - name: nfs-volume
        persistentVolumeClaim:
          claimName: test-nfs-pvc
status: {}

[root@master-1 yamlfiles]# echo '<h1>nfs test successfully!</h1>' > /nfsshare/nfspath/index.html
```

分别访问被调度到node-1和node-2的pod，均能正常访问到`/nfsshare/nfspath/`目录下的文件，访问的内容也是一致的，不像`hostpath`那样在不同节点访问的内容不一致，也不像`local`那样只能调度到指定的节点，也不像`emptydir`那样删除了pod数据就销毁了(如果`persistentVolumeReclaimPolicy: Recycle`就会删除)。所以nfs算是结合了它们的优点的一种分布式存储。

```
[root@master-1 yamlfiles]# kubectl  apply -f test-nfs.yaml 
service/test-nfs-svc created
deployment.apps/test-nfs created

[root@master-1 yamlfiles]# kubectl  get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
test-nfs-755d88f4bb-2vxh9       1/1     Running   0          10s   192.168.2.149   node-2   <none>           <none>
test-nfs-755d88f4bb-nwpsd       1/1     Running   0          10s   192.168.1.172   node-1   <none>           <none>
test-nfs-755d88f4bb-qcjvl       1/1     Running   0          10s   192.168.2.148   node-2   <none>           <none>

[root@master-1 yamlfiles]# kubectl  exec -it test-nfs-755d88f4bb-qcjvl /bin/bash
root@test-nfs-755d88f4bb-qcjvl:/# cat /usr/share/nginx/html/index.html 
<h1>nfs test successfully!</h1>
root@test-nfs-755d88f4bb-qcjvl:/# curl localhost:80
<h1>nfs test successfully!</h1>

[root@master-1 yamlfiles]# kubectl  exec -it test-nfs-755d88f4bb-nwpsd /bin/bash
root@test-nfs-755d88f4bb-nwpsd:/# cat /usr/share/nginx/html/index.html 
<h1>nfs test successfully!</h1>
root@test-nfs-755d88f4bb-nwpsd:/# curl localhost:80
<h1>nfs test successfully!</h1>
```

下面是阿里云的nas存储pvc例子，跟nfs差不多，使用的felxVolume是独立的存储插件，但是需要提前在每个节点目录`/usr/libexec/kubernetes/kubelet-plugins/volume/exec/`都部署driver插件驱动，前面提到的emptydir，hostpath，local等都是与k8s耦合的存储插件。

```
apiVersion: v1
kind: PersistentVolume
metadata:
  namespace: 
  name: data-pv
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 3Gi
  flexVolume:
    driver: alicloud/nas
    options:
      modeType: non-recursive
      path: /share/data
      server: xxx.nas.aliyuncs.com
      vers: '3'
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nas
  volumeMode: Filesystem

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: 
  name: data-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nas
  resources:
    requests:
      storage: 3Gi
```

>详细的pvc各种字段含义参考官方文档：`https://kubernetes.io/docs/concepts/storage/persistent-volumes/`

关于持久化pod数据的方法还有很多，选了几个常见的实践了下，像`configMap, secret, downwardAPI`下篇再实践吧。下面来个小彩蛋。

#### 10.如何为kubectl delete加上删除提示

执行`kubectl delete`命令默认没有删除提示，按了enter就直接删除了，在生产环境中很容易造成误删，后果很严重，所以可以自己加一层提示。以下是弹出提示的脚本`add_prompt`

```
#!/bin/bash

if [[ "delete" == $2 ]]; then
    read -r -p "This command would delete k8s resources, please confirm again !!! [yes/no] " input
    case $input in
        [yY][eE][sS])
                $@
            ;;
    
        [nN][oO])
            echo "Operation cancelled !"
            ;;
    
        *)
            echo "Invalid input..."
            exit 1
            ;;
    esac
else
    $@
fi
```

设置别名替换原命令

```
[root@master-1 ~]# chmod +x /usr/bin/add_prompt
[root@master-1 ~]# vim /etc/profile
...
# Functions and aliases go in /etc/bashrc
alias 'kubectl'='/usr/bin/add_prompt /usr/bin/kubectl'
...
[root@master-1 ~]# source /etc/profile
```

执行`kubectl delete`命令时会弹出确认提示，输入`yes`确认后才会删除

```
[root@master-1 yamlfiles]# kubectl get pod
NAME                       READY   STATUS    RESTARTS   AGE
my-nginx-8d97ff5d6-f65md   1/1     Running   0          43m
my-nginx-8d97ff5d6-jx6sq   1/1     Running   0          43m
my-nginx-8d97ff5d6-wpq8b   1/1     Running   0          43m
[root@master-1 yamlfiles]# kubectl delete -f my-nginx.yaml 
This command would delete k8s resources, please confirm again !!! [yes/no] y
Invalid input...
[root@master-1 yamlfiles]# kubectl delete -f my-nginx.yaml 
This command would delete k8s resources, please confirm again !!! [yes/no] yes
deployment.apps "my-nginx" deleted
[root@master-1 yamlfiles]# kubectl get pod 
No resources found in default namespace.
```

#### 11. 如何挂载配置文件，密码等敏感信息到pod？

**To Be Continue ~**
