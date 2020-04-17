---
title: "在docker镜像中加入环境变量"
date: 2019-06-24T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://s1.ax1x.com/2020/04/17/JEooX4.md.jpg"
categories:
  - "docker"
tags:
  - "docker"
---


#### 前言
>reference:https://vsupalov.com/docker-build-time-env-values/

很多时候，我们需要**在docker镜像中加入环境变量**，本人了解的有2种方法可以做到

#### 第一种

使用`docker run --env VARIABLE=VALUE image:tag`直接添加变量，**适用于直接用docker启动的项目**

```
root@ubuntu:/home/vickey/test_build# docker run --rm -it --env TEST=2 ubuntu:latest
root@2bbe75e5d8c7:/# env |grep "TEST"
TEST=2
```

#### 第二种

使用dockerfile的`ARG`和`ENV`添加变量，**适用于不能用`docker run`命令启动的项目**，如k8s

> ARG只在构建docker镜像时有效（dockerfile的RUN指令等），在镜像创建了并用该镜像启动容器后则无效（后面有例子验证）。但可以配合ENV指令使用使其在创建后的容器也可以生效。

```
ARG buildtime_variable=default_value        # if not set default_value buildtime_variable would be set ''
ENV env_var_name=$buildtime_variable
```

在构建映像时，可以使用`--build-arg buildtime_variable=other_value`覆盖dockerfile里的变量值`default_value`

```
$ docker build --build-arg buildtime_variable=other_value --tag image:tag
```
#### 多阶段构建
但是有时我们只是临时需要环境变量或文件，最后的镜像是不需要的这些变量的，设置ARG和ENV值就会在Docker镜像中留下痕迹，比如保密信息等。**多阶段构建**可以用来去掉包含保密信息的镜像。

- dockerfile

```
FROM ubuntu as intermediate     # 为第一阶段构建设置别名，在第二阶段引用
ARG TEST=deault_value       # 设置环境变量
ENV ENV_TEST=$TEST      # 设置环境变量
RUN echo test > /home/test.txt
RUN cat /home/test.txt      # 查看文件是否正常
RUN env
RUN env |grep TEST      # 查看环境变量是否已设置

FROM ubuntu
COPY --from=intermediate /home/test.txt /home/another_test.txt      # 将第一阶段生成的文件拷贝到第二阶段镜像中
RUN cat /home/another_test.txt      # 查看拷贝的文件是否正常
RUN env
RUN env |grep TEST      # 查看环境变量是否已设置
```

- 多阶段构建

```
root@ubuntu:/home/vickey/test_build# docker build --build-arg TEST=2 -t ubuntu:test-multi-build --no-cache -f ./dockerfile .
Sending build context to Docker daemon   2.56kB
Step 1/12 : FROM ubuntu as intermediate
 ---> 94e814e2efa8
Step 2/12 : ARG TEST=deault_value
 ---> Running in 7da9180a6311
Removing intermediate container 7da9180a6311
 ---> 7e8420f3ecf2
Step 3/12 : ENV ENV_TEST=$TEST
 ---> Running in 256788d179ce
Removing intermediate container 256788d179ce
 ---> 11cf4e0581d9
Step 4/12 : RUN echo test > /home/test.txt
 ---> Running in c84799ba3831
Removing intermediate container c84799ba3831
 ---> f578ca5fe373
Step 5/12 : RUN cat /home/test.txt
 ---> Running in dbf8272fd10c
test
Removing intermediate container dbf8272fd10c
 ---> 9f8720732878
Step 6/12 : RUN env
 ---> Running in 9050cd9e36c9
HOSTNAME=9050cd9e36c9
HOME=/root
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TEST=2
PWD=/
ENV_TEST=2
Removing intermediate container 9050cd9e36c9
 ---> f1f4daf42cc0
Step 7/12 : RUN env |grep TEST
 ---> Running in 1cc7968144f5
TEST=2
ENV_TEST=2
Removing intermediate container 1cc7968144f5
 ---> c6d390887082
Step 8/12 : FROM ubuntu
 ---> 94e814e2efa8
Step 9/12 : COPY --from=intermediate /home/test.txt /home/another_test.txt
 ---> 27480a945fab
Step 10/12 : RUN cat /home/another_test.txt
 ---> Running in de1f5a999fe1
test
Removing intermediate container de1f5a999fe1
 ---> 16c630eb6b1b
Step 11/12 : RUN env
 ---> Running in d13becd5ae77
HOSTNAME=d13becd5ae77
HOME=/root
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PWD=/
Removing intermediate container d13becd5ae77
 ---> ea52a6e9a7b2
Step 12/12 : RUN env |grep TEST
 ---> Running in 7ef585772e9a
The command '/bin/sh -c env |grep TEST' returned a non-zero code: 1
```
从dockerfile的注释和构建时对应步骤的输出可以看出，第一阶段的环境变量和文件，在第二阶段复制了文件后，环境变了没有复制过来（最后一步报错了，就是因为环境变量不存在了），正好达到我们想要的结果---将环境变量保密信息等删除而保留了我们想要的文件。

#### 验证第二种方法实例（可忽略）

- 同一目录下创建个dockerfile和至少一个文件

```
root@ubuntu:/home/vickey/test_build# tree -L 2
.
├── dockerfile
└── whatever
0 directories, 2 files
root@ubuntu:/home/vickey/test_build# cat dockerfile 
FROM ubuntu
```
dockfile
```
FROM ubuntu
```

- docker构建镜像

```
root@ubuntu:/home/vickey/test_build# docker build --build-arg TEST=1 -t ubuntu:test-build -f ./dockerfile .
Sending build context to Docker daemon   2.56kB
Step 1/1 : FROM ubuntu
 ---> 94e814e2efa8
[Warning] One or more build-args [TEST] were not consumed
Successfully built 94e814e2efa8
Successfully tagged ubuntu:test-build
root@ubuntu:/home/vickey/test_build# docker images |grep test-build
ubuntu                                        test-build          94e814e2efa8        3 months ago        88.9MB
```

- 用镜像启动个容器

```
root@ubuntu:/home/vickey/test_build# docker run --rm -it ubuntu:test-build
root@383c30a1d6f5:/# env
HOSTNAME=383c30a1d6f5
PWD=/
HOME=/root
TERM=xterm
SHLVL=1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/env
root@383c30a1d6f5:/# env|grep "TEST"
root@383c30a1d6f5:/# 
```
发现并没有构建镜像时`--build-arg TEST=1`传入的变量，因为构建时有个`[Warning] One or more build-args [TEST] were not consumed`, 需要在dockfile里面引用`TEST`才行。

- 在dockerfile加入变量
```
FROM ubuntu
ARG TEST
```
- 重新构建并创建容器
```
root@ubuntu:/home/vickey/test_build# docker build --build-arg TEST=1 -t ubuntu:test-build -f ./dockerfile .
Sending build context to Docker daemon   2.56kB
Step 1/2 : FROM ubuntu
 ---> 94e814e2efa8
Step 2/2 : ARG TEST
 ---> Running in f9ccda7b3a4b
Removing intermediate container f9ccda7b3a4b
 ---> dc95b444ffc5
Successfully built dc95b444ffc5
Successfully tagged ubuntu:test-build
root@ubuntu:/home/vickey/test_build# docker run --rm -it ubuntu:test-build
root@370dd8b3d2ca:/# env
... ignore...
root@370dd8b3d2ca:/# env|grep "TEST"
root@370dd8b3d2ca:/# 
```
发现没有warning了，但还是没有变量`TEST`，因为**ARG只在构建docker镜像时有效，在镜像创建了并用该镜像启动容器后则无效**。但可以配合`ENV`指令使用使其在创建后的容器也可以生效。下面加入`ENV`看看

- 在dockerfile加入`ENV`

```
FROM ubuntu
ARG TEST
ENV ENV_TEST=$TEST
```

- 再次构建并启动容器

```
root@ubuntu:/home/vickey/test_build# docker build --build-arg TEST=1 -t ubuntu:test-build -f ./dockerfile .
Sending build context to Docker daemon   2.56kB
Step 1/3 : FROM ubuntu
 ---> 94e814e2efa8
Step 2/3 : ARG TEST
 ---> Using cache
 ---> dc95b444ffc5
Step 3/3 : ENV ENV_TEST=$TEST
 ---> Running in d8cd0014b36b
Removing intermediate container d8cd0014b36b
 ---> ebd198fcb586
Successfully built ebd198fcb586
Successfully tagged ubuntu:test-build
root@ubuntu:/home/vickey/test_build# docker run --rm -it ubuntu:test-build
root@f9dd6cf0bb47:/# env|grep "TEST"
ENV_TEST=1
```

很好，这时dockerfile的ARG变量`TEST`已经传给ENV变量`ENV_TEST`了。我们已经可以使用docker构建时传入的变量了。
