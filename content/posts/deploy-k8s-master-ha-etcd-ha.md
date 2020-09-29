---
title: "k8s master ha 及 etcd ha 部署"
date: 2020-09-26T03:10:06Z
description:  "k8s master ha 及 etcd ha 部署"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/C6F2C7BED410466290E090E8B018D223?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "etcd"
  - "ha"
---

#### 一、etcd ha

1.在3台主机安装 etcd 

```
yum install etcd -y
```

2.然后执行`vim /etc/etcd/etcd.conf`分别修改配置为对应主机 ip 和 `ETCD_NAME` ，其中 `ETCD_INITIAL_CLUSTER` 填写所有 `etcd` 成员的地址，`ETCD_LISTEN_CLIENT_URLS` 和 `ETCD_ADVERTISE_CLIENT_URLS` 为 `0.0.0.0` 监听所有 `etcd` 成员地址。

```
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.0.1:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_NAME="infra0"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.1:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_INITIAL_CLUSTER="infra0=http://192.168.0.1:2380,infra1=http://192.168.0.2:2380,infra2=http://192.168.0.3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
```
```
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.0.2:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_NAME="infra1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.2:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_INITIAL_CLUSTER="infra0=http://192.168.0.1:2380,infra1=http://192.168.0.2:2380,infra2=http://192.168.0.3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
```
```
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.0.3:2380"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_NAME="infra2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.3:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_INITIAL_CLUSTER="infra0=http://192.168.0.1:2380,infra1=http://192.168.0.2:2380,infra2=http://192.168.0.3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
```

3.启动所有`etcd`成员

```
[root@master01 ~]# systemctl start etcd
[root@master01 ~]# systemctl status etcd
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2020-09-24 17:27:14 CST; 12min ago
 Main PID: 12024 (etcd)
    Tasks: 44
   Memory: 104.0M
   CGroup: /system.slice/etcd.service
           └─12024 /usr/bin/etcd --name=infra0 --data-dir=/var/lib/etcd/default.etcd --listen-client-urls=http://0.0.0.0:2379
```

4.设置开机启动

```
systemctl enable etcd
```

5.验证

查看所有成员都是 `running` 即可开始部署 `k8s master ha`

```
[root@master01 ~]# etcdctl member list
b988b9a63841195: name=infra2 peerURLs=http://192.168.0.3:2380 clientURLs=http://0.0.0.0:2379 isLeader=false
ba7d8361e0f422bb: name=infra1 peerURLs=http://192.168.0.2:2380 clientURLs=http://0.0.0.0:2379 isLeader=false
c883f9e325d8667d: name=infra0 peerURLs=http://192.168.0.1:2380 clientURLs=http://0.0.0.0:2379 isLeader=true
```

#### 二、k8s master ha

>这里默认你已经安装好docker及k8s组件，由于本实例安装是基于arm64架构的华为鲲鹏服务器，支持的版本为`1.14.2`比较低，如果在阿里云等x86架构的服务器安装可以安装最新版的`1.19.2`，目的是实践`k8s master ha`，所以版本不是很重要。

>使用arm64的可以参考`https://support.huaweicloud.com/dpmg-kunpengcpfs/kunpengk8s_04_0001.html`

>使用x86架构的可以参考`https://mp.weixin.qq.com/s/5wKjRjV49SQWfoO1DIMvsg`

1.使用`kubeadm config print init-defaults > kubeadm-init.yaml`生成 k8s master 初始化配置文件并参考下面修改对应配置
```
apiVersion: kubeadm.k8s.io/v1beta1
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  #advertiseAddress: 192.168.0.1
  # 监听所有master成员
  advertiseAddress: 0.0.0.0
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: master01
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta1
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
# 云厂商的elb ip，或自建的haproxy的ip:port
controlPlaneEndpoint: "192.168.0.5"
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  # etcd 堆叠部署时的配置
  external:
    dataDir: /var/lib/etcd
    endpoints:
    - http://192.168.0.1:2379
    - http://192.168.0.2:2379
    - http://192.168.0.3:2379
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.14.2
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.20.0.0/16
  # pod子网网段
  podSubnet: "10.244.0.0/16"
scheduler: {}
```

2.在其中一台master执行初始化即可`kubeadm init --config kubeadm-init.yaml`。输出如下。

```
[root@master01 ~]# kubeadm init --config kubeadm-init.yaml 
W0924 17:23:40.177218   11062 strict.go:54] error unmarshaling configuration schema.GroupVersionKind{Group:"kubeadm.k8s.io", Version:"v1beta1", Kind:"ClusterConfiguration"}: error unmarshaling JSON: while decoding JSON: json: unknown field "dataDir"
[init] Using Kubernetes version: v1.14.2
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Activating the kubelet service
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [master01 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.20.0.1 192.168.0.1 192.168.0.5]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] External etcd mode: Skipping etcd/ca certificate authority generation
[certs] External etcd mode: Skipping etcd/server certificate authority generation
[certs] External etcd mode: Skipping apiserver-etcd-client certificate authority generation
[certs] External etcd mode: Skipping etcd/peer certificate authority generation
[certs] External etcd mode: Skipping etcd/healthcheck-client certificate authority generation
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 15.2156 seconds
[upload-config] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.14" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --experimental-upload-certs
[mark-control-plane] Marking the node master01 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node master01 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities 
and service account keys on each node and then running the following as root:

  kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 \
    --experimental-control-plane 	  

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 
```

3.将初始化的证书等复制到其他2台master

`CONTROL_PLANE_IPS`改为其他2台`master`的`ip`或`hostname`分别执行下面的脚本复制证书

```
USER=root
CONTROL_PLANE_IPS="master02"
for host in ${CONTROL_PLANE_IPS}; do
    ssh "${USER}"@$host "mkdir -p /etc/kubernetes/pki/etcd"
    scp /etc/kubernetes/pki/ca.* "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/sa.* "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/front-proxy-ca.* "${USER}"@$host:/etc/kubernetes/pki/
    scp /etc/kubernetes/admin.conf "${USER}"@$host:/etc/kubernetes/
done
```

4.使用初始化的输出信息在其他2台master执行命令加入到控制平面

```
  kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 \
    --experimental-control-plane 
```

输出如下

```
[root@master02 ~]# kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
>     --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 \
>     --experimental-control-plane 
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks before initializing the new control plane instance
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [master02 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.20.0.1 192.168.0.2 192.168.0.5]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[certs] Using the existing "sa" key
[kubeconfig] Generating kubeconfig files
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Using existing kubeconfig file: "/etc/kubernetes/admin.conf"
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[check-etcd] Skipping etcd check in external mode
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.14" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
[control-plane-join] using external etcd - no local stacked instance added
[upload-config] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[mark-control-plane] Marking the node master02 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node master02 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]

This node has joined the cluster and a new control plane instance was created:

* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane (master) label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.


To start administering your cluster from this node, you need to run the following as a regular user:

	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.
```

```
[root@master02 ~]# mkdir -p $HOME/.kube
[root@master02 ~]# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@master02 ~]# sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

5.为集群加入work节点

```
kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 
```

输出如下

```
[root@node01 ~]# kubeadm join 192.168.0.5:6443 --token abcdef.0123456789abcdef \
>     --discovery-token-ca-cert-hash sha256:76bea16bfdabf50327db6ff3c449d2993e6c5072037b2d22cf3f2e47ec0b2e81 
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.14" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

6.部署网络插件flannel，配置文件可以去码云拉取比较快。

>`https://gitee.com/mirrors/flannel/blob/master/Documentation/kube-flannel.yml`

```
kubectl apply -f  kube-flannel.yaml 
```

7.使用`kubectl get cs` `kubectl get nodes`等查看集群组件/节点正常即可
```
[root@master01 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-1               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"} 
```

```
[root@master01 ~]# kubectl get nodes 
NAME            STATUS   ROLES    AGE   VERSION
node03          Ready    <none>   1h   v1.14.2
node02          Ready    <none>   1h   v1.14.2
node01          Ready    <none>   1h   v1.14.2
master01        Ready    master   1h   v1.14.2
master02        Ready    master   1h   v1.14.2
master03        Ready    master   1h   v1.14.2
```

8.验证高可用

将任意一台master节点关机，然后部署一个应用看看是否正常，正常即为高可用集群。

```
[root@master01 ~]# kubectl get nodes 
NAME            STATUS      ROLES    AGE   VERSION
node03          Ready       <none>   1h   v1.14.2
node02          Ready       <none>   1h   v1.14.2
node01          Ready       <none>   1h   v1.14.2
master01        NotReady    master   1h   v1.14.2
master02        Ready       master   1h   v1.14.2
master03        Ready       master   1h   v1.14.2
```

`test.yaml`

```
apiVersion: apps/v1beta1 
kind: Deployment 
metadata: 
  name: nginx-deployment 
spec: 
  replicas: 2 
  template 
    metadata: 
      labels: 
        app: nginx 
    spec: 
      containers: 
      - name: nginx 
        image: nginx
        ports: 
          - containerPort: 80
```

部署应用仍然可以正常部署。

```
[root@master01 ~]# kubectl apply -f test.yaml 
[root@master01 ~]# kubectl get pod -w
NAME                                READY   STATUS              RESTARTS   AGE
nginx-deployment-56db997f77-btw56   0/1     ContainerCreating   0          5s
nginx-deployment-56db997f77-cwf2l   0/1     ContainerCreating   0          5s
nginx-deployment-56db997f77-cwf2l   1/1     Running             0          7s
nginx-deployment-56db997f77-btw56   1/1     Running             0          9s
```

#### 参考文章

>`https://www.cnblogs.com/51wansheng/p/10234036.html`

>`https://www.cnblogs.com/uglyliu/p/11142421.html`

>`https://gitee.com/mirrors/flannel/blob/master/Documentation/kube-flannel.yml`
