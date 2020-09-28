---
title: "从零开始部署k8s"
date: 2020-06-06T03:10:06Z
description:  "从零开始部署k8s"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/7BE310B6A34944D39F0CDCB2CBE72CE0?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "kubeadm"
---

#### 零、机器配置要求

master节点最低要求2C4G，本人用的虚拟机centos7镜像，1个master 2个node，磁盘都是30GB 

#### 一、 yum更新

##### `yum update -y`报错

```
cant find a baseurl for repo xxx
```

##### 解决方案
1.`ip addr`找到主机网卡，一般第二个(我这里是ens33)
```
[root@localhost ~]# ip addr
...
2: ens33: xxx
```

2.将对应网卡文件的值修改为`ONBOOT=yes`

```
[root@localhost ~]# vi /etc/sysconfig/network-scripts/ifcfg-ens33
...
ONBOOT=yes
```

3.重启网络

```
[root@localhost ~]# service network restart
```

#### 二、 修改主机名

在`centos7`下使用`hostnamectl`即可修改主机名（修改完需要在新窗口才能看到变化）
```
[root@localhost ~]# hostname
localhost.localdomain
[root@localhost ~]# hostnamectl set-hostname master-1
# 重新打开的窗口就会显示如下修改后的主机名了
[root@master-1 ~]# 
```

以此类推修改其他主机名

#### 三、centos7安装docker

>`https://docs.docker.com/engine/install/centos/`

```
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce-18* docker-ce-cli-18* containerd.io -y
systemctl start docker

cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "oom-score-adjust": -1000,
    "registry-mirrors": ["http://hub-mirror.c.163.com"],
    "storage-driver": "overlay2",
    "storage-opts":["overlay2.override_kernel_check=true"]
}
EOF


systemctl daemon-reload
systemctl restart docker

# 设置开机启动
systemctl enable docker
```

查看docker version

```
[root@master-3 ~]# docker version
...
 Version:           19.03.10
...
```

#### 四、使用国内镜像源

>`https://zhuanlan.zhihu.com/p/59048502`

新建镜像源

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
# if aarch64 use below
#baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-aarch64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

关闭selinux防火墙

```
setenforce 0
```

安装指定版本`kubelet`, `kubeadm`, `kubectl`(否则默认安装最新版)

```
[root@master-1 ~]# yum install kubeadm-1.16.9 kubelet-1.16.9 kubectl-1.16.9 -y
```

安装成功如下所示

```
...
Installed:
  kubeadm.x86_64 0:1.18.3-0                                     kubectl.x86_64 0:1.18.3-0                                     kubelet.x86_64 0:1.18.3-0                                    

Dependency Installed:
  conntrack-tools.x86_64 0:1.4.4-7.el7              cri-tools.x86_64 0:1.13.0-0                     kubernetes-cni.x86_64 0:0.7.5-0       libnetfilter_cthelper.x86_64 0:1.0.0-11.el7      
  libnetfilter_cttimeout.x86_64 0:1.0.0-7.el7       libnetfilter_queue.x86_64 0:1.0.2-2.el7_2       socat.x86_64 0:1.7.3.2-2.el7         

Complete!
[root@master-1 ~]#
```

开机启动kubelet

```
[root@master-2 ~]# systemctl enable kubelet && systemctl start kubelet
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.
```

我这里使用`kubectl`无法自动补全命令，所以安装一下补全命令

```
yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

#### 五、初始化集群

所有节点初始化时需要关闭防火墙及交换分区

```
systemctl stop firewalld
sudo swapoff -a
```

所有节点初始化时需要开启桥接

```
## 在文件/etc/sysctl.conf加入
net.bridge.bridge-nf-call-iptables = 1

## 执行命令
sysctl -p
```

检查通过后执行`kubeadm init`会拉镜像，但有墙在，会卡住

```
[root@master-1 ~]# kubeadm init --kubernetes-version=v1.16.9 --apiserver-advertise-address 192.168.229.130 --pod-network-cidr=10.244.0.0/16
[init] Using Kubernetes version: v1.16.9
...
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
```

按照提示执行命令来获取我们需要安装哪些版本的镜像

>`https://zhuanlan.zhihu.com/p/46341911`

```
[root@master-1 ~]# kubeadm config images list
I0602 16:57:20.428992   22384 version.go:251] remote version is much newer: v1.18.3; falling back to: stable-1.16
k8s.gcr.io/kube-apiserver:v1.16.10
k8s.gcr.io/kube-controller-manager:v1.16.10
k8s.gcr.io/kube-scheduler:v1.16.10
k8s.gcr.io/kube-proxy:v1.16.10
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.3.15-0
k8s.gcr.io/coredns:1.6.2
```

然后将获取到的镜像及版本放到脚本并执行即可将镜像拉取下来(阿里云没有1.16.10，我改为1.16.9了), 注意：如果你的服务器架构是`aarch64`的，除了`coredns`所有镜像后面都得加`-arm64`, 如`kube-apiserver-arm64:v1.16.9`

```
[root@master-1 ~]# vim pull_image.sh
IMAGES=(
 kube-apiserver:v1.16.9
 kube-controller-manager:v1.16.9
 kube-scheduler:v1.16.9
 kube-proxy:v1.16.9
 pause:3.1
 etcd:3.3.15-0
 coredns:1.6.2
)

for imageName in ${IMAGES[@]} ; do
    docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
    docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
    docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
done
```
在集群的**所有节点**都拉取镜像
```
[root@master-1 ~]# sh pull_image.sh
```

有了镜像现在master节点就可以执行初始化了，这里`10.244.0.0/16`是flannel默认的网段，你也可以改为`192.168.0.0/18`但同时`flannel.yaml`文件中也要改`"Network": "192.168.0.0/18"`

```
[root@master-1 ~]# kubeadm init --kubernetes-version=v1.16.9 --apiserver-advertise-address 192.168.229.130 --pod-network-cidr=10.244.0.0/16

...
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.229.130:6443 --token ito18s.dzayiyv8k56a5s5c \
    --discovery-token-ca-cert-hash sha256:41064492d09103e5a4b1fb3951d1835647be741d92e0dca8e6df1edcf66a901c 
    
```

这里又提示我们master节点部署分2步走

1.第一步，复制证书到指定目录，普通用户要想有权限访问集群也需要执行该步骤，如果没有sudo权限需要将普通用户加入到sudoers里

```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

2.第二步在所有集群节点部署网络，根据给出的网址选择自己需要的网络类型部署，我这里选的是`flannel`

```
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/
```


部署flannel（flannel需要访问的quay.io镜像地址被墙了，所以要先想办法拉到镜像才能部署成功，所有节点都需要该镜像）


```
[root@master-1 ~]# cat pull_image_flannel.sh


IMAGES=(
 flannel:v0.12.0-amd64
)

for imageName in ${IMAGES[@]} ; do
    docker pull quay-mirror.qiniu.com/coreos/$imageName
    docker tag quay-mirror.qiniu.com/coreos/$imageName quay.io/coreos/$imageName
    docker rmi quay-mirror.qiniu.com/coreos/$imageName
done
```
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

如果执行不了就手动GitHub复制一份来执行

>`https://github.com/coreos/flannel/blob/master/Documentation/kube-flannel-aliyun.yml`

```
kubectl apply -f kube-flannel.yml
```

部署weave (可选)

```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

3.第三步是利用token将node节点加入master节点

```
#### work节点加入master节点
[root@master-2 ~]# kubeadm join 192.168.229.130:6443 --token ztqec5.hfwtbvfol9dd47oa \
    --discovery-token-ca-cert-hash sha256:41064492d09103e5a4b1fb3951d1835647be741d92e0dca8e6df1edcf66a901c 
...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.


#### 加入成功
[root@master-1 ~]# kubectl get nodes
master-1   Ready    master   37m     v1.16.9
node-1     Ready    <none>   2m10s   v1.16.9
node-2     Ready    <none>   57s     v1.16.9
```

部署个nginx试试

```
[root@master-1 ~]# kubectl create deployment my-nginx --image=nginx -o yaml --dry-run > my-nginx.yaml
[root@master-1 ~]# kubectl apply -f my-nginx.yaml 
deployment.apps/my-nginx created
[root@master-1 ~]# kubectl get pod -o wide -w
NAME                       READY   STATUS              RESTARTS   AGE     IP            NODE     NOMINATED NODE   READINESS GATES
my-nginx-f97c96f6d-7tj75   0/1     ContainerCreating   0          2m42s   <none>        node-2   <none>           <none>
my-nginx-f97c96f6d-h7k5t   1/1     Running             0          2m59s   10.244.1.7   node-1   <none>           <none>
my-nginx-f97c96f6d-7tj75   1/1     Running             0          2m54s   10.244.2.2   node-2   <none>           <none>
[root@master-1 ~]# kubectl get pod -o wide 

```

访问正常

```
[root@master-1 ~]# curl 10.244.2.2
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

注意：token有效期24小时，过期需要重新生成后再执行加入master命令才能成功

```
#### master 节点
[root@master-1 ~]# kubeadm token create
oxmee9.t4gd4e5606ov5uf2
[root@master-1 ~]# kubeadm token list
TOKEN                     TTL       EXPIRES                     USAGES                   DESCRIPTION   EXTRA GROUPS
oxmee9.t4gd4e5606ov5uf2   23h       2020-06-05T11:00:43+08:00   authentication,signing   <none>        system:bootstrappers:kubeadm:default-node-token
```

#### 五、结语

这样基本的k8s就算部署成功了，之后就可以随便玩了，只是在自己电脑用虚拟机部署整天开机关机不方便，防火墙，swap都要关闭，集群才能正常工作，土豪请直接买服务器吧。
