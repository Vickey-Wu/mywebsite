---
title: "docker更换root目录"
date: 2021-04-22T03:10:06Z
description:  "docker更换root目录"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/1DEE64A6D9A84BA0BC3C7A02725B811D?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "docker"
tags:
  - "docker"
---

#### 步骤

1. 查看目前`docker root`目录是在哪，然后停止docker服务

```
[root@km1 ~]# docker info |grep "Docker Root Dir"
 Docker Root Dir: /var/lib/docker


[root@km1 containers]# service docker stop
Redirecting to /bin/systemctl stop docker.service
Warning: Stopping docker.service, but it can still be activated by:
  docker.socket
```

>这里有个大坑，**停止docker后千万不要再使用docker的任何命令查看相关信息**，否则docker进程就又会被唤起，会导致丢失原来镜像及容器数据，或原有容器和新启动的容器启动报没有权限读写tmp目录。下面使用了`docker ps`后停止的docker服务又被唤起了。

```
[root@km1 docker]# ps -ef |grep docker
root      3219     1  0 21:23 ?        00:00:00 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root      3412  1556  0 21:25 pts/0    00:00:00 grep --color=auto docker
[root@km1 docker]# service docker stop
Redirecting to /bin/systemctl stop docker.service
Warning: Stopping docker.service, but it can still be activated by:
  docker.socket
[root@km1 docker]# ps -ef |grep docker
root      3431  1556  0 21:25 pts/0    00:00:00 grep --color=auto docker
[root@km1 docker]# docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
[root@km1 docker]# ps -ef |grep docker
root      3439     1  6 21:25 ?        00:00:00 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root      3598  1556  0 21:25 pts/0    00:00:00 grep --color=auto docker
```

2. 新建或修改`/etc/docker/daemon.json`文件里面的root目录，并将`/var/lib/docker`目录移动至指定目录，我这里是`/home/docker_root_tmp`

```

[root@km1 containers]# cat /etc/docker/daemon.json
{
  "data-root": "/home/docker_root_tmp"
}


[root@km1 containers]# mv /var/lib/docker/ /home/docker
```

3. 启动docker服务，验证目录已经更改为`/home/docker_root_tmp`

```
[root@km1 containers]# service docker start
Redirecting to /bin/systemctl start docker.service


[root@km1 containers]# docker info |grep "Docker Root Dir"
 Docker Root Dir: /home/docker_root_tmp
```
