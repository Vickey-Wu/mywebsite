---
title: "docker原理总结"
date: 2018-11-21T03:10:06Z
description: "dockefile basic"
type: "post"
image: "https://s1.ax1x.com/2020/04/16/JFEZUf.md.jpg"
categories:
  - "docker"
tags:
  - "docker"
  - "namespace"
  - "cgroups"
  - "rootfs"
---

#### 为啥docker会火

docker解决了PaaS中最为棘手也最亟待解决的一个问题：解决了应用打包和发布这一困扰运维人员多年的技术难题，

#### docker如何解决打包发布问题的

Docker 等大多数 Linux 容器来说(docker的Mac, win容器原理与linux容器是不一样的，它们是基于虚拟化技术实现的)，Namespace 技术是用来修改进程视图(进程隔离)的主要方法, Cgroups 技术是用来制造约束(资源限制)的主要手段。rootfs构成linux容器文件系统

一个正在运行的 Linux 容器，其实可以被“一分为二”地看待：
- 一组联合挂载在`/var/lib/docker/overlay2`上的rootfs，这一部分我们称为“容器镜像”（Container Image），是容器的静态视图。
- 一个由`Namespace + Cgroups`构成的隔离环境，这一部分我们称为“容器运行时”（Container Runtime），是容器的动态视图。

#### docker是如何修改进程视图做到进程隔离的

docker使用Linux 里面的 Namespace 机制来隔离进程。Namespace 其实是 Linux 创建新进程的可选参数 `CLONE_NEWPID`, `CLONE_NEWNS`等等。用clone()系统调用创建一个新进程时，在参数中指定 `CLONE_NEWPID` 参数，新创建的这个进程就是一个全新的进程空间，它的 PID 是 1。但在宿主机真实的进程空间里，这个进程的 PID 还是真实的数值，比如 100。
```
# pid namespace
clone(main_function, stack_size, CLONE_NEWPID | SIGCHLD, NULL);

# mount namespace
clone(main_function, stack_size, CLONE_NEWNS | SIGCHLD , NULL);
```

所以docker容器实际是在创建容器进程时指定了这个进程所需的一组namespace参数的特殊进程而已。


#### docker用到了哪些namespace

用到了linux操作系统的pid, mount, uts, ipc(进程间通信), network, userd等Namespace。其中Mount Namespace是基于对linux命令chroot 的不断改良才被发明出来的，它是Linux操作系统里的第一个Namespace

#### docker容器与虚拟机有啥区别

- 虚拟机性能消耗大于docker容器

虚拟机自身需要200m内存来运行，运行在虚拟机的应用通信需要先经过虚拟机这一层再到达宿主机，这也需要CPU，内存，IO等性能消耗。

docker容器化的应用，只是宿主机上一个指定了这个进程所需的一组namespace参数的特殊进程，它没有因为虚拟化而带来的性能损耗。

- docker容器没有虚拟机隔离彻底

容器只是宿主机上指定了这个进程所需的一组namespace参数的特殊进程，那么多个容器之间使用的就还是同一个宿主机的操作系统内核。

在linux内核中，有很多资源和对象是不能被Namespace化的，比如时间，也就是说在容器里改变了系统时间，整个宿主机的时间都会改变。

相比之下，运行在宿主机之上的虚拟机Hypervisor对运行在虚拟机上的应用进程的隔离环境负责而不受宿主机操作系统内核影响，而运行在宿主机上的docker容器只是一个特殊进程是会受到宿主机操作系统内核的影响的。

#### 使用namespace就可以创建隔离的docker容器了为啥还要cgroups做资源限制

前面也提到了，虽然namespace机制新创建的进程是一个全新的进程空间，但在宿主机真实的进程空间里，这个进程的 PID 还是真实的数值，因为容器是共享宿主机操作系统内核的，所有不同容器间的进程是不会相互影响，但资源是共享的，宿主机的资源可能被其中一个进程占用完了从而导致另一个容器进程没有资源而挂了，所以就必须做资源限制。

#### cgroups能限制哪些资源

Linux Cgroups全称linux Control Group，它能限制一个进程组能够使用的资源上限，如CPU、内存、磁盘、网络带宽等等。

在linux下的`/sys/fs/cgroup`目录下就可以看到各种资源限制目录
```
root@vickey:/sys/fs/cgroup# ls
blkio  cpu  cpuacct  cpu,cpuacct  cpuset  devices  freezer  hugetlb  memory  net_cls  net_cls,net_prio  net_prio  perf_event  pids  systemd
root@vickey:/sys/fs/cgroup# mount -t cgroup
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
```

对于Docker Linux容器项目来说，它们只需要在每个子系统下面，为每个容器创建一个控制组（即创建一个新目录），然后在启动容器进程之后，把这个进程的 PID 填写到对应控制组的 tasks 文件中就可以了。

#### docker linux容器文件系统是怎么实现的

```
# mount namespace
clone(main_function, stack_size, CLONE_NEWNS | SIGCHLD , NULL);
```

docker 使用`mount namespace`实现容器目录挂载，使用linux命令`chroot`改变进程的根目录到你指定的位置。Mount Namespace 正是基于对 chroot 的不断改良才被发明出来的，它也是 Linux 操作系统里的第一个 Namespace。

挂载在容器根目录上、用来为容器进程提供隔离后执行环境的文件系统，就是所谓的“容器镜像”，也就是`rootfs`（根文件系统）。rootfs 是一个操作系统所包含的文件、配置和目录，因此应用以及它运行所需要的所有依赖都被封装在了一起。但`rootfs`并不包括操作系统内核，同一台机器上的所有容器，都是共享宿主机操作系统内核的。


Docker在镜像的设计中引入了层（`layer`）的概念。也就是说，用户制作镜像的每一步操作都会生成一个层，也就是一个增量`rootfs`。而层是用Union File System实现的，UnionFS能将多个不同位置的目录联合挂载（union mount）到同一个目录下，最新首选存储驱动程序overlay2,目录为：`/var/lib/docker/overlay2`, docker 18.06及更早版本的首选存储驱动程序是aufs, 目录为：`/var/lib/docker/aufs`

#### 容器的rootfs由哪些部分组成

```
root@vickey:/var/lib/docker# ls
builder  buildkit  containers  image  network  overlay2  plugins  runtimes  swarm  tmp  trust  volumes
root@vickey:/var/lib/docker# ls overlay2/
acffe6c9dee1570f2aebc19106faed409aad2f20b8b842329dad707b11e0f27e
acffe6c9dee1570f2aebc19106faed409aad2f20b8b842329dad707b11e0f27e-init
85d43d1afe8cd6bcc459aa78095e244376da10d86d3c3661ce0a61f150c0eea0
...
```

- 第一部分，只读层。对应rootfs 最下面的层，挂载方式都是只读的（ro+wh，即 readonly+whiteout
- 第二部分，可读写层，挂载方式为：rw，即 read write，可读写层专门用来存放你修改 rootfs 后产生的增量，无论是增、删、改，都发生在这里
- 第三部分，Init 层，它是 Docker 项目单独生成的一个内部层，专门用来存放 /etc/hosts、/etc/resolv.conf 等信息。这样用户执行`docker commit`只会提交可读写层，所以是不包含init层的内容

#### dockerfile是啥

Docker提供了一种更便捷制作rootfs的方式就是Dockerfile。它使用一些标准的原语(大写的`FROM, RUN, CMD`等等)描述我们所要构建的 Docker 镜像。在构建镜像时将按顺序将每一行原语构建成一个层，最后联合成一个包含所有这些层的镜像。

#### Dockerfile命令常用的有哪些

```
FROM:基于哪个镜像实现
EXPOSE:容器内应用可以使用的端口
ENV:容器内环境变量
RUN:执行安装依赖等命令
ADD:添加宿主机文件到容器里，会自动解压文件到容器
COPY:添加宿主机文件到容器里，不会自动解压
VOLUME:指定挂载目录，docker run -v可以挂载宿主机文件到容器里
WORKDIR:容器启动后，docker exec -i进入容器的默认目录
CMD:容器启动命令，如果docker run后面有启动命令会覆盖CMD的命令
ENTRYPOINT:与CMD相同，容器启动命令，但不会被覆盖。
           默认情况下，Docker 会供一个隐含的 ENTRYPOINT，即：/bin/sh -c "bash cmd"。
           它和 CMD 都是 Docker 容器进程启动所必需的参数，完整执行格式是：“ENTRYPOINT CMD”。
```

#### docker常用命令有哪些

在安装了docker的宿主机就可以查看docker有哪些命令

```
docker --help
Commands:
  login       Log in to a Docker registry
  ps          List containers
  pull        Pull an image or a repository from a registry
  push        Push an image or a repository to a registry
  run         Run a command in a new container
  build       Build an image from a Dockerfile
  start       Start one or more stopped containers
  restart     Restart one or more containers
  rm          Remove one or more containers
  commit      Create a new image from a container's changes
  cp          Copy files/folders between a container and the local filesystem
  images      List images
```

查看docker子命令，如：docker build

```
docker build --help
  -t, --tag list                Name and optionally a tag in the 'name:tag' format
  -f, --file string             Name of the Dockerfile (Default is 'PATH/Dockerfile')
```

#### 参考文章

>https://time.geekbang.org/column/intro/116

>https://docs.docker.com/engine/reference/builder/

>https://www.vickey-wu.com/dockerfile-basic/
