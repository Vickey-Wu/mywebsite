---
title: "开机启动docker容器里的程序"
date: 2018-12-10T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://s1.ax1x.com/2020/04/16/JF8mm8.md.jpg"
categories:
  - "docker"
tags:
  - "docker"
---

#### steps

1./etc/rc.local 开机启动命令
```
exec 1>/tmp/rc.local.log 2>&1  # send stdout and stderr from rc.local to a log file
set -x                         # tell sh to display commands before execution
/usr/bin/docker start spider
sleep 3
sh /root/init.sh
exit 0
```

2.在宿主机运行 用于在容器里面启动程序的脚本

```
docker exec -i spider /bin/bash /docker_init.sh
```

3.docker_init.sh 用于启动容器里面程序的命令

```
scrapyd
```
以防万一增加执行权限
```
chmod +x docker_init.sh
```
将其cp至容器里面
```
docker cp docker_init.sh spider:/docker_init.sh
```
spider容器映射端口：5000:5000 6800:6800
挂载目录：`/tmp/data:/data`

4.重启

重启服务器之后就会在spider容器里面启动scrapyd，我们访问ip:6800即可看到scrapyd已经启动了

5.注意点

第一次重启时正常的，但第二次重启，如果没有将容器里面的twistd.pid文件删除掉则会报Another twistd server is running....，我们可以将docker_init.sh路径映射出来，然后在宿主机删除它即可，删除的命令写到rc.local去，这样每次重启都不会有问题了
