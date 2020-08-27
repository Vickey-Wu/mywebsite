---
title: "helm安装与使用"
date: 2020-08-25T03:10:06Z
description:  "helm安装与使用"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/CC82F34E4CAB458F913FD79C5ED2FDA1?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "helm"
tags:
  - "helm"
  - "helm3"
---

#### [helm架构](https://steemit.com/kubernetes/@cloudman6/helm-kubernetes-48)

>Helm 有两个重要的概念：chart 和 release

>chart 是创建一个应用的信息集合，包括各种 Kubernetes 对象的配置模板、参数定义、依赖关系、文档说明等。chart 是应用部署的自包含逻辑单元。可以将 chart 想象成 apt、yum 中的软件安装包

>release 是 chart 的运行实例，代表了一个正在运行的应用。当 chart 被安装到 Kubernetes 集群，就生成一个 release。chart 能够多次安装到同一个集群，每次安装都是一个 release

>简单的讲：Helm 客户端负责管理 chart；Tiller 服务器负责管理 release（helm3已没有Tiller）

#### helm安装

有墙找个香港服务器下好或用别人的已下好包

- download

```
// 国内服务器
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
// 国外服务器
curl -o "https://get.helm.sh/helm-canary-linux-amd64.tar.gz" heml3.tar.gz
```

- install helm3

```
tar -zxvf helm-canary-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/helm
```

- install helm2

```
// 解压安装helm
tar -zxvf helm-v2.10.0-linux-amd64.tar.gz 
mv linux-amd64/helm /usr/local/bin/helm
// 拉取tiller镜像
docker pull vickeywu/tiller:v2.10.0
docker tag vickeywu/tiller:v2.10.0 gcr.io/kubernetes-helm/tiller:v2.10.0
docker rmi vickeywu/tiller:v2.10.0
```

- helm命令补全

```
source <(helm completion bash)
helm init   // helm3 不用init
```

#### helm3常用命令

1. 创建chart

```
helm create hello
[root@master-1 tmp]# tree hello/
hello/
├── charts
├── Chart.yaml
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```

2. 调试chart

>helm install ${name} --dry-run --debug会模拟安装
chart，并输出每个模板生成的 YAML 内容。

```
[root@master-1 tmp]# helm install hello --dry-run --debug hello/
install.go:160: [debug] Original chart version: ""
install.go:177: [debug] CHART PATH: /tmp/hello

NAME: hello
LAST DEPLOYED: Tue Aug 25 14:08:05 2020
NAMESPACE: default
STATUS: pending-install
REVISION: 1
USER-SUPPLIED VALUES:
{}
......
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=hello,app.kubernetes.io/instance=hello" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace default port-forward $POD_NAME 8080:80
```

3. 检查yaml文件语法

```
[root@master-1 tmp]# helm lint --strict hello
==> Linting hello
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

4. helm 打包、安装、访问、删除应用
```
[root@master-1 tmp]# helm package ./hello/
Successfully packaged chart and saved it to: /tmp/hello-0.1.0.tgz

[root@master-1 tmp]# helm install hello-tgz hello-0.1.0.tgz
......
[root@master-1 tmp]# kubectl get pod
NAME                                  READY   STATUS        RESTARTS   AGE
hello-tgz-7cbd7bd5b8-8vgn8            0/1     Running       0          4s


[root@master-1 tmp]# kubectl port-forward hello-tgz-7cbd7bd5b8-rjd5b 8080:80 &
[1] 77453
[root@master-1 tmp]# Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
[root@master-1 tmp]# curl localhost:8080
Handling connection for 8080
......
<title>Welcome to nginx!</title>
......


[root@master-1 tmp]# helm delete hello-tgz 
release "hello-tgz" uninstalled
[root@master-1 tmp]# kubectl get pod
NAME                                  READY   STATUS        RESTARTS   AGE
hello-tgz-7cbd7bd5b8-8vgn8            0/1     Terminating   0          101s
```

5. helm从目录安装、删除应用

```
[root@master-1 tmp]# helm install hello hello/
NAME: hello
LAST DEPLOYED: Tue Aug 25 14:51:19 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=hello,app.kubernetes.io/instance=hello" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace default port-forward $POD_NAME 8080:80
[root@master-1 tmp]# helm list
NAME 	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART      	APP VERSION
hello	default  	1       	2020-08-25 14:51:19.294525784 +0800 CST	deployed	hello-0.1.0	1.16.0

[root@master-1 tmp]# kubectl get pod
NAME                                  READY   STATUS        RESTARTS   AGE
hello-7bd9497468-v7tr9                1/1     Running       0          6s

[root@master-1 tmp]# helm delete hello 
release "hello" uninstalled
[root@master-1 tmp]# kubectl get pod
NAME                                  READY   STATUS        RESTARTS   AGE
hello-7bd9497468-v7tr9                0/1     Terminating   0          45s
```

6. helm repo添加更新

```
[root@master-1 tmp]# helm repo list 
Error: no repositories to show
[root@master-1 tmp]# helm repo add stable http://aliacs-k8s-cn-hangzhou.oss-cn-hangzhou.aliyuncs.com/app/charts/
"stable" has been added to your repositories
[root@master-1 tmp]# helm repo add incubator http://aliacs-k8s-cn-hangzhou.oss-cn-hangzhou.aliyuncs.com/app/charts-incubator/
"incubator" has been added to your repositories


[root@master-1 tmp]# helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "stable" chart repository
...Successfully got an update from the "incubator" chart repository
Update Complete. ⎈ Happy Helming!⎈ 


[root@master-1 tmp]# helm repo list
NAME     	URL                                                              
stable   	http://aliacs-k8s-cn-hangzhou.oss-cn-hangzhou.aliyuncs.com/app/charts/          
incubator	http://aliacs-k8s-cn-hangzhou.oss-cn-hangzhou.aliyuncs.com/app/charts-incubator/
```

7. 从已有helm repo安装、删除应用

```
[root@master-1 tmp]# helm search repo nginx
NAME                       	CHART VERSION	APP VERSION	DESCRIPTION                                       
incubator/ack-ingress-nginx	1.34.2       	0.30.0     	An Nginx Ingress Controller that uses ConfigMap...

[root@master-1 tmp]# helm install inc-nginx incubator/ack-ingress-nginx
NAME: inc-nginx
LAST DEPLOYED: Tue Aug 25 16:07:26 2020
NAMESPACE: default
.......
[root@master-1 tmp]# kubectl get pod
NAME                                                      READY   STATUS        RESTARTS   AGE
inc-nginx-ack-ingress-nginx-controller-577d7fc94c-866bc   1/1     Running       0          2m36s


[root@master-1 tmp]# helm delete inc-nginx
release "inc-nginx" uninstalled
[root@master-1 tmp]# kubectl get pod
NAME                                                      READY   STATUS        RESTARTS   AGE
inc-nginx-ack-ingress-nginx-controller-577d7fc94c-866bc   1/1     Terminating   0          4m43s
```

8. 回滚版本

```
[root@master-1 tmp]# helm rollback hello 1
Rollback was a success! Happy Helming!
[root@master-1 tmp]# helm list
NAME 	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART      	APP VERSION
hello	default  	2       	2020-08-25 16:35:05.238075915 +0800 CST	deployed	hello-0.1.1	1.12.0     
[root@master-1 tmp]# helm rollback hello 2
Rollback was a success! Happy Helming!
[root@master-1 tmp]# helm list
NAME 	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART      	APP VERSION
hello	default  	3       	2020-08-25 16:35:17.055624497 +0800 CST	deployed	hello-0.1.1	1.12.0     
[root@master-1 tmp]# helm history hello 
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION     
1       	Tue Aug 25 16:33:11 2020	superseded	hello-0.1.1	1.12.0     	Install complete
2       	Tue Aug 25 16:35:05 2020	superseded	hello-0.1.1	1.12.0     	Rollback to 1   
3       	Tue Aug 25 16:35:17 2020	deployed  	hello-0.1.1	1.12.0     	Rollback to 2   
```

#### 参考文档

>`https://developer.aliyun.com/lesson_1651_16513?spm=5176.270689.1397405.34.64d8f5f8qjyuIr`
