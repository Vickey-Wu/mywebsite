---
title: "编写go程序并将其部署到k8s示例"
date: 2020-12-10T03:10:06Z
description:  "编写go程序并将其部署到k8s示例"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/BB659B06E2944806A2CD7D375EBFD7AF?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "go"
  - "docker"
  - "k8s"
tags:
  - "go"
  - "docker"
  - "k8s"
---

#### linux安装或更新go

```
[root@ecs-6272 ~]# wget https://golang.org/dl/go1.15.6.linux-amd64.tar.gz
[root@ecs-6272 ~]# tar -C /usr/local -xzf go1.15.6.linux-amd64.tar.gz
[root@ecs-6272 ~]# echo "export PATH=$PATH:/usr/local/go/bin">>/etc/profile
[root@ecs-6272 ~]# source /etc/profile
[root@ecs-6272 ~]# go version
go version go1.15.6 linux/amd64
```
#### 创建项目架构

```
[root@ecs-6272 project]# tree -L 4 yourprojectname/
yourprojectname/
├── bin
└── src
    └── demo
        └── base
```

#### 设置代理

```
[root@ecs-6272 base]# echo "export GO111MODULE=on">>/etc/profile
[root@ecs-6272 base]# echo "export GOPROXY=https://goproxy.cn">>/etc/profile
[root@ecs-6272 base]# source /etc/profile

[root@ecs-6272 base]# go env
GO111MODULE="on"
GOARCH="amd64"
GOBIN=""
GOCACHE="/root/.cache/go-build"
GOENV="/root/.config/go/env"
GOEXE=""
GOFLAGS=""
GOHOSTARCH="amd64"
GOHOSTOS="linux"
GOINSECURE=""
GOMODCACHE="/root/go/pkg/mod"
GONOPROXY=""
GONOSUMDB=""
GOOS="linux"
GOPATH="/root/go"
GOPRIVATE=""
GOPROXY="https://goproxy.cn"
GOROOT="/usr/local/go"
GOSUMDB="sum.golang.org"
GOTMPDIR=""
GOTOOLDIR="/usr/local/go/pkg/tool/linux_amd64"
GCCGO="gccgo"
AR="ar"
CC="gcc"
CXX="g++"
CGO_ENABLED="1"
GOMOD="/root/project/medialab/src/demo/base/go.mod"
CGO_CFLAGS="-g -O2"
CGO_CPPFLAGS=""
CGO_CXXFLAGS="-g -O2"
CGO_FFLAGS="-g -O2"
CGO_LDFLAGS="-g -O2"
PKG_CONFIG="pkg-config"
GOGCCFLAGS="-fPIC -m64 -pthread -fmessage-length=0 -fdebug-prefix-map=/tmp/go-build044050033=/tmp/go-build -gno-record-gcc-switches"
```

不设置的话下载将出现`timeout`

```
[root@ecs-6272 base]# go get -u github.com/gin-gonic/gin
go get github.com/gin-gonic/gin: module github.com/gin-gonic/gin: Get "https://proxy.golang.org/github.com/gin-gonic/gin/@v/list": dial tcp 216.58.200.49:443: i/o timeout
```
#### 使用go.mod处理依赖

```
[root@ecs-6272 base]# cd yourprojectname/src/demo/base
[root@ecs-6272 base]# go mod init demo/base
go: creating new go.mod: module demo/base
[root@ecs-6272 base]# ls
go.mod
[root@ecs-6272 base]# cat go.mod 
module demo/base

go 1.15
```

>关于依赖可以参考: `https://studygolang.com/articles/26096`

#### 下载gin框架

```
[root@ecs-6272 base]# go get -u github.com/gin-gonic/gin
go: downloading github.com/gin-gonic/gin v1.6.3
go: github.com/gin-gonic/gin upgrade => v1.6.3
go: downloading github.com/mattn/go-isatty v0.0.12
......

[root@ecs-6272 base]# ls
go.mod  go.sum 
```

下载后自动将gin的依赖写入到go.mod

```
[root@ecs-6272 base]# cat go.mod 
module demo/base

go 1.15

require (
	github.com/gin-gonic/gin v1.6.3 // indirect
	github.com/go-playground/validator/v10 v10.4.1 // indirect
	github.com/golang/protobuf v1.4.3 // indirect
	github.com/json-iterator/go v1.1.10 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.1 // indirect
	github.com/ugorji/go v1.2.1 // indirect
	golang.org/x/crypto v0.0.0-20201208171446-5f87f3452ae9 // indirect
	golang.org/x/sys v0.0.0-20201207223542-d4d67f95c62d // indirect
	google.golang.org/protobuf v1.25.0 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
)
```

下载gin实例代码

```
[root@ecs-6272 base]# curl https://raw.githubusercontent.com/gin-gonic/examples/master/basic/main.go > main.go
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  1332  100  1332    0     0    357      0  0:00:03  0:00:03 --:--:--   357
[root@ecs-6272 base]# ls
go.mod  go.sum  main.go
```

运行示例代码，在浏览器访问`IP:8080/ping`返回`pong`即表示成功运行起来了。我们就可以在`main.go`里面添加修改自己的路由了。

```
[root@ecs-6272 base]# go run main.go 
[GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.

[GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
 - using env:	export GIN_MODE=release
 - using code:	gin.SetMode(gin.ReleaseMode)

[GIN-debug] GET    /ping                     --> main.setupRouter.func1 (3 handlers)
[GIN-debug] GET    /user/:name               --> main.setupRouter.func2 (3 handlers)
[GIN-debug] POST   /admin                    --> main.setupRouter.func3 (4 handlers)
[GIN-debug] Listening and serving HTTP on :8080
[GIN] 2020/12/10 - 10:37:58 | 404 |         575ns |   x.x.x.x | GET      "/"
[GIN] 2020/12/10 - 10:37:58 | 404 |         776ns |   x.x.x.x | GET      "/favicon.ico"
[GIN] 2020/12/10 - 10:38:03 | 200 |      28.152µs |   x.x.x.x | GET      "/ping"
```

>关于如何写go项目的更多步骤参考官方示例: `https://golang.org/doc/code.html`

#### 生成二进制可执行文件

生成的文件放在`$GOPATH/bin/`目录下，也可以设置`GOBIN`来更改存放位置

```
[root@ecs-6272 base]# go install demo/base          # or use 'go install .'
[root@ecs-6272 base]# go env |grep GOPATH
GOPATH="/root/go"
[root@ecs-6272 base]# go env |grep GOBIN
GOBIN=""
[root@ecs-6272 base]# go env -w GOBIN=/somewhere/else/bin
```

进入文件存放目录，执行二进制文件发现报错，因为我们没有将这个目录加入到环境变量，加入后即可正常运行。但在本地运行不是我们的目的，所以可以忽略这一步。

```
[root@ecs-6272 bin]# cd /root/go/bin
[root@ecs-6272 bin]# base
-bash: base: command not found

[root@ecs-6272 base]# export PATH=$PATH:/root/go/bin
[root@ecs-6272 bin]# env|grep -i path
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/go/bin:/root/go/bin

[root@ecs-6272 bin]# base
[GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.

[GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
 - using env:	export GIN_MODE=release
 - using code:	gin.SetMode(gin.ReleaseMode)

[GIN-debug] GET    /ping                     --> main.setupRouter.func1 (3 handlers)
[GIN-debug] GET    /user/:name               --> main.setupRouter.func2 (3 handlers)
[GIN-debug] POST   /admin                    --> main.setupRouter.func3 (4 handlers)
[GIN-debug] Listening and serving HTTP on :8080
[GIN] 2020/12/10 - 10:44:56 | 200 |      34.448µs |   116.24.66.184 | GET      "/ping"
```

#### 将二进制文件打包进docker镜像

将我们生成的二进制文件复制到一个目录中，并编写`Dockerfile`文件将其打包成镜像

```
[root@ecs-6272 tmp]# ls
base  Dockerfile

[root@ecs-6272 tmp]# cat Dockerfile 
FROM golang:latest
ADD ./base /go/bin/base
EXPOSE 8080
CMD [ "sh", "-c", "./bin/base"]

[root@ecs-6272 tmp]# docker build -t vickeywu/demo -f Dockerfile .
Sending build context to Docker daemon  14.96MB
Step 1/4 : FROM golang:latest
 ---> 6d8772fbd285
Step 2/4 : ADD ./base /go/bin/base
 ---> 921f92e82b30
Step 3/4 : EXPOSE 8080
 ---> Running in d7f2c5543a16
Removing intermediate container d7f2c5543a16
 ---> f7041f438079
Step 4/4 : CMD [ "sh", "-c", "./bin/base"]
 ---> Running in 8db5cae5cb74
Removing intermediate container 8db5cae5cb74
 ---> a51614b7ea6d
Successfully built a51614b7ea6d
Successfully tagged vickeywu/demo:latest
```

#### 在k8s部署

我的服务器已经部署了k8s，可以用`kubectl create`快速生成yaml文件，然后加入`service`文件，并暴露端口`30080`，然后在浏览器访问`IP:30080/ping`返回`pong`即表示成功。

```
[root@ecs-6272 tmp]# kubectl create deployment demo --image=vickeywu/demo --dry-run -o yaml >demo.yam


[root@ecs-6272 tmp]# cat demo.yaml 
---
apiVersion: v1
kind: Service
metadata:
  name: demo-svc
spec:
  selector:
    app: demo
  type: NodePort
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
      nodePort: 30080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: demo
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: demo
    spec:
      containers:
      - image: vickeywu/demo
        name: demo
        imagePullPolicy: IfNotPresent
        resources: {}
status: {}
```

使用`kubectl apply -f demo.yaml`部署`deployment, service`

```
[root@ecs-6272 tmp]# kubectl apply -f  demo.yaml 
service/demo-svc created
deployment.apps/demo created

[root@ecs-6272 tmp]# kubectl get pod
NAME                                      READY   STATUS    RESTARTS   AGE
demo-59b998d7d6-52nfp                     1/1     Running   0          8m43s
nfs-client-provisioner-7fc4bcf9c7-4vbvf   1/1     Running   0          15d
[root@ecs-6272 tmp]# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
demo-svc     NodePort    10.101.81.150   <none>        8080:30080/TCP   116s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP          16d
[root@ecs-6272 tmp]# kubectl logs -f demo-59b998d7d6-52nfp 
[GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.

[GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
 - using env:	export GIN_MODE=release
 - using code:	gin.SetMode(gin.ReleaseMode)

[GIN-debug] GET    /ping                     --> main.setupRouter.func1 (3 handlers)
[GIN-debug] GET    /user/:name               --> main.setupRouter.func2 (3 handlers)
[GIN-debug] POST   /admin                    --> main.setupRouter.func3 (4 handlers)
[GIN-debug] Listening and serving HTTP on :8080
[GIN] 2020/12/10 - 08:05:01 | 404 |         704ns |      10.244.0.1 | GET      "/"
[GIN] 2020/12/10 - 08:05:13 | 200 |     101.781µs |      10.244.0.1 | GET      "/ping"
[GIN] 2020/12/10 - 08:13:33 | 404 |         786ns |      10.244.0.1 | GET      "/"
[GIN] 2020/12/10 - 08:13:33 | 404 |         892ns |      10.244.0.1 | GET      "/favicon.ico"
[GIN] 2020/12/10 - 08:13:37 | 200 |       8.154µs |      10.244.0.1 | GET      "/ping"
```

#### 参考文章

>goproxy: `https://blog.csdn.net/sinat_34241861/article/details/110232463`

>official example: `https://golang.org/doc/code.html`

>gin example: `https://xueyuanjun.com/post/21861`
