---
title: "k8s实践记录（五）"
date: 2020-09-03T03:10:06Z
description:  "k8s实践记录（五）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/7BE310B6A34944D39F0CDCB2CBE72CE0?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

#### 17.如何对pod做权限限制？(准入控制篇)

在[上篇记录](https://mp.weixin.qq.com/s/QHriBOXnBLfo3ASTGdE14Q)已经了解了认证、授权流程，在请求通过认证和授权之后、对象被持久化之前，还需要通过准入控制流程后才能到达`api-server`。接下来就**先了解下准入控制流程，然后实践下动态准入控制过程**。

#### 准入控制器作用

准入控制流程就是请求得通过各种准入控制器变更、验证的流程。

**准入控制器**由`MutatingAdmissionWebhook`和`ValidatingAdmissionWebhook`两个特殊的控制器组成，并编译进 kube-apiserver 二进制文件，只能由集群管理员配置。

准入控制器可以执行 “验证” 和（或） “变更” 操作。变更（mutating）控制器可以修改被其接受的对象；验证（validating）控制器则不行。

准入控制过程分为两个阶段。第一阶段，运行变更准入控制器。第二阶段，运行验证准入控制器。某些控制器既是变更准入控制器又是验证准入控制器。任何一个阶段的任何控制器拒绝了该请求，则整个请求将立即被拒绝，并向终端用户返回一个错误。

#### 动态准入控制器实践

除了内置的准入控制插件，`Admission`插件也可以作为扩展被独立开发，并以运行时所配置的`webhook`的形式运行。接下来实践一下动态准入控制器。注意：k8s版本至少为`v1.16`（以便使用 admissionregistration.k8s.io/v1 API）或者`v1.9`（以便使用 admissionregistration.k8s.io/v1beta1 API）。我的集群是`1.16.9`，所以`v1, v1beta1`都支持。

```
[root@master-1 yamlfiles]# kubectl api-versions |grep admission
admissionregistration.k8s.io/v1
admissionregistration.k8s.io/v1beta1
```

`Admission webhook`是一种用于接收准入请求并对其进行处理的`HTTP`回调机制。可以定义两种类型的`admission webhook`，即`validating admission webhook和mutating admission webhook`


- 检查是否已启用这两个webhook

查看`api-server`是否启用`MutatingAdmissionWebhook, ValidatingAdmissionWebhook`，如果要禁用就将`enable-admission-plugins`改为`disable-admission-plugins`

```
[root@master-1 yamlfiles]# kubectl get pods -n kube-system kube-apiserver-master-1 -o yaml|grep admission
    - --enable-admission-plugins=NodeRestriction
```

发现并没有启用。在`/etc/kubernetes/manifests/kube-apiserver.yaml`文件中添加两个准入控制器，保存重启`api-server`即可启用。

```
[root@master-1 yamlfiles]# cd /etc/kubernetes/manifests/
[root@master-1 manifests]# vim kube-apiserver.yaml
......
    - --enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
......

[root@master-1 yamlfiles]# kubectl delete pod -n kube-system kube-apiserver-master-1 
pod "kube-apiserver-master-1" deleted

[root@master-1 yamlfiles]# kubectl get pods -n kube-system kube-apiserver-master-1 -o yaml|grep admission
    - --enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

- 克隆测试代码

克隆GitHub上的大佬编写好的webhook测试代码，这个仓库的`deployment`目录下存放各种部署时要用到的yaml文件；`main.go`主要定义了一个服务请求入口；`webhook.go`则定义了`/mutate和/validate`路由请求时要做的操作。服务请求类型为`Deployment, Service`的`/mutate`路由时是否含有指定的`annotation, label`等，没有的话就自动给它们加上，然后经过`validation`阶段没问题就会成功创建请求的类型资源；服务请求类型为`Deployment, Service`的`/validate`路由时是否含有指定的`label`，没有则会报错说哪个标签没有设置，如果已具有指定标签则会直接创建请求的类型资源。下面一起实践下吧。

```
[root@master-1 src]# git clone https://github.com/Vickey-Wu/admission-webhook-example.git
```

- 构建镜像（可选）

如需使用自定义的镜像才需要构建镜像，然后在`admission-webhook-example/deployment/deployment.yaml`引用自定义镜像，将`image`替换为自己的`dockerhub`仓库地址，如替换成我的地址`image: vickeywu/admission-webhook-example:v1`（如果没有需先在`https://hub.docker.com/`注册）

```
[root@master-1 src]# cd admission-webhook-example/
[root@master-1 admission-webhook-example]# export DOCKER_USER=vickeywu
[root@master-1 admission-webhook-example]# docker login 
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: vickeywu
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

[root@master-1 admission-webhook-example]# ./build 
......
Successfully built 55d04819a0e0
Successfully tagged vickeywu/admission-webhook-example:v1
The push refers to repository [docker.io/vickeywu/admission-webhook-example]
886aeac29654: Pushed 
50644c29ef5a: Mounted from library/alpine 
v1: digest: sha256:d4d1df6e9e896b93adfa0aff0da86ed57c41b414540c17f148b5473741ff3642 size: 740
```

- 生成证书并挂载到secret

运行仓库生成证书脚本`./deployment/webhook-create-signed-cert.sh`。这个脚本作用就是完成上一篇实践的**认证流程**，以便测试服务可以与`api-server`通信。

```
[root@master-1 admission-webhook-example]# ./deployment/webhook-create-signed-cert.sh 
creating certs in tmpdir /tmp/tmp.poX38v4Omz 
Generating RSA private key, 2048 bit long modulus
..+++
........+++
e is 65537 (0x10001)
certificatesigningrequest.certificates.k8s.io "admission-webhook-example-svc.default" deleted
certificatesigningrequest.certificates.k8s.io/admission-webhook-example-svc.default created
NAME                                    AGE   REQUESTOR          CONDITION
admission-webhook-example-svc.default   0s    kubernetes-admin   Pending
certificatesigningrequest.certificates.k8s.io/admission-webhook-example-svc.default approved
secret/admission-webhook-example-certs created
[root@master-1 admission-webhook-example]# kubectl get secrets admission-webhook-example-certs 
NAME                              TYPE     DATA   AGE
admission-webhook-example-certs   Opaque   2      11s
```

- 部署webhook server服务

首先从`deployment/rbac.yaml`创建一个`ServiceAccount: admission-webhook-example-sa`和具有多种资源操作权限的`ClusterRole`，然后用`ClusterRoleBinding`绑定起来。

```
[root@master-1 admission-webhook-example]# kubectl apply -f deployment/rbac.yaml 
serviceaccount/admission-webhook-example-sa created
clusterrole.rbac.authorization.k8s.io/admission-webhook-example-cr created
clusterrolebinding.rbac.authorization.k8s.io/admission-webhook-example-crb created
```
然后使用这个有权限的`serviceAccount: admission-webhook-example-sa`和创建的`secret: admission-webhook-example-certs`就可以完成我们之前实践的**认证、授权流程了**，接着就是创建**准入控制流程**的测试服实例来测试这个过程。

```
[root@master-1 admission-webhook-example]# kubectl apply -f  deployment/deployment.yaml 
deployment.apps/admission-webhook-example-deployment created
[root@master-1 admission-webhook-example]# kubectl apply -f deployment/service.yaml 
service/admission-webhook-example-svc created

[root@master-1 admission-webhook-example]# kubectl get pod
NAME                                                    READY   STATUS        RESTARTS   AGE
admission-webhook-example-deployment-7c5d7566d7-9vkxq   1/1     Running       0          3m26s

[root@master-1 admission-webhook-example]# kubectl get svc
NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
admission-webhook-example-svc   ClusterIP   10.105.38.222    <none>        443/TCP   3m28s
```

##### 1.测试validatingwebhook阶段

- 配置validation webhook

```
[root@master-1 admission-webhook-example]# cat ./deployment/validatingwebhook.yaml | ./deployment/webhook-patch-ca-bundle.sh > ./deployment/validatingwebhook-ca-bundle.yaml
```

部署好服务后，先测试`validatingwebhook`阶段。创建相应的`validatingwebhookconfigurations.admissionregistration.k8s.io`实例，但创建配置实例要用到有权限的证书，执行上面的命令后会将`ca`证书内容填充到原本为空的字段`caBundle`，但我实践时发现并没有替换，只好手动替换为下面输出内容即可，当然你实践时如果正常就忽略手动替换就好了。

```
[root@master-1 admission-webhook-example]# kubectl config view --raw|grep certificate-authority-data|awk -F': ' '{print $2}'
LS0tLS1C......tLS0tLQo=
```
```
[root@master-1 admission-webhook-example]# cat deployment/validatingwebhook-ca-bundle.yaml 
      ......
      caBundle: LS0tLS1C......tLS0tLQo=
      ......
```

搞定证书后，创建相应的`validatingwebhookconfigurations.admissionregistration.k8s.io`实例

```
[root@master-1 admission-webhook-example]# kubectl apply -f deployment/validatingwebhook-ca-bundle.yaml 
validatingwebhookconfiguration.admissionregistration.k8s.io/validation-webhook-example-cfg created
[root@master-1 admission-webhook-example]# kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io 
NAME                             CREATED AT
validation-webhook-example-cfg   2020-09-03T03:17:38Z
```
- 测试validation webhook

创建完实例就可以测试了。因为`deployment/validatingwebhook.yaml`设置了`namespaceSelector`，具有`admission-webhook-example: enabled`标签的`namespace`我们部署的`validation webhook`才有效。所以先给`namespace`打个标签再测试。

```
namespaceSelector:
  matchLabels:
	admission-webhook-example: enabled
	
[root@master-1 admission-webhook-example]# kubectl label namespace default admission-webhook-example=enabled
namespace/default labeled
```

从下面测试结果可以看到有6个特定标签的`sleep-with-labels.yaml`就可以正常创建，没有标签的`sleep.yaml`就报错了。**这就验证了我们部署的validationwebhook对pod是生效的，它会验证pod是否有指定标签，没有的话就会阻止创建，有的话就通过验证成功创建**

```
[root@master-1 admission-webhook-example]# kubectl apply -f deployment/sleep.yaml
Error from server (required labels are not set): error when creating "deployment/sleep.yaml": admission webhook "required-labels.vickey-wu.com" denied the request: required labels are not set

[root@master-1 admission-webhook-example]# cat deployment/sleep-with-labels.yaml 
......
  labels:
    app.kubernetes.io/name: sleep
    app.kubernetes.io/instance: sleep
    app.kubernetes.io/version: "0.1"
    app.kubernetes.io/component: dummy
    app.kubernetes.io/part-of: admission-webhook-example
    app.kubernetes.io/managed-by: kubernetes
    ......


[root@master-1 admission-webhook-example]# kubectl apply -f  deployment/sleep-with-labels.yaml 
deployment.apps/sleep created
```

##### 2.测试mutatingwebhook阶段

- 配置mutating webhook

因为`mutatingwebhook`阶段是发生在`validatingwebhook`之前的，它会检查请求是否符合我们部署的`admissionwebhook`服务的规则，如果不符合就会根据部署的服务制定的规则修改请求，在这里我们部署的测试服务会自动给没有标签的`deployment`的创建请求加上标签，也就是上面`sleep-with-labels.yaml`的6个标签，但标签值默认都是`not_available`。

首先参考上面**配置validation webhook**步骤将`ca`证书**替换**，然后创建`mutatingwebhook`实例

```
[root@master-1 admission-webhook-example]# cat ./deployment/mutatingwebhook.yaml | ./deployment/webhook-patch-ca-bundle.sh > ./deployment/mutatingwebhook-ca-bundle.yaml

[root@master-1 admission-webhook-example]# kubectl apply -f  deployment/mutatingwebhook-ca-bundle.yaml 
mutatingwebhookconfiguration.admissionregistration.k8s.io/mutating-webhook-example-cfg created
[root@master-1 admission-webhook-example]# kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io 
NAME                           CREATED AT
mutating-webhook-example-cfg   2020-09-03T03:41:47Z
```

- 测试mutating webhook

将之前测试的`deployment`删除，不删就同名了无法创建，或者自己改个名字也行。然后创建原本就没有带标签的`deployment`发现并没有报错了，因为它已经被自动加上了指定的6个标签，所以也就成功创建了。**这也就验证了mutatingwebhook有效**。

```
[root@master-1 admission-webhook-example]# kubectl delete -f deployment/sleep-with-labels.yaml 
deployment.apps "sleep" deleted

[root@master-1 admission-webhook-example]# kubectl apply -f  deployment/sleep.yaml 
deployment.apps/sleep created
[root@master-1 admission-webhook-example]# kubectl get pod
NAME                                                    READY   STATUS        RESTARTS   AGE
admission-webhook-example-deployment-7c5d7566d7-9vkxq   1/1     Running       0          25m
sleep-bb596f69d-dlc5s                                   1/1     Running       0          79s

[root@master-1 admission-webhook-example]# kubectl get deployments.apps sleep  -o yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    admission-webhook-example.vickey-wu.com/status: mutated
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2020-09-03T06:15:18Z"
  generation: 1
  labels:
    app.kubernetes.io/component: not_available
    app.kubernetes.io/instance: not_available
    app.kubernetes.io/managed-by: not_available
    app.kubernetes.io/name: not_available
    app.kubernetes.io/part-of: not_available
    app.kubernetes.io/version: not_available
    ......
```

至此，准入控制流程实践就完成了。当然k8s有一堆的准入控制器实现各种默认功能，下面摘要了些作为记录。之前实践的基本都是无状态应用，使用的都是`deployment`，下篇实践下有状态应用，使用`statefulset`，看下它们的区别。

#### 部分控制器摘要

>完整控制器列表，查看`https://kubernetes.io/zh/docs/reference/access-authn-authz/admission-controllers/`

- AlwaysPullImages 

>该准入控制器会修改每一个新创建的 Pod 的镜像拉取策略为 Always 。 这在多租户集群中是有用的，这样用户就可以放心，他们的私有镜像只能被那些有凭证的人使用。

- DefaultStorageClass 

>该准入控制器监测没有请求任何特定存储类的`PersistentVolumeClaim`对象的创建，并自动向其添加默认存储类。这样，没有任何特殊存储类需求的用户根本不需要关心它们，它们将获得默认存储类。

- DefaultTolerationSeconds 

>该准入控制器为`Pod`设置默认的容忍度，在5分钟内容忍`notready:NoExecute`和`unreachable:NoExecute`污点，5分钟后没有这个污点的容忍度的`pod`将被驱逐。

- MutatingAdmissionWebhook 

>该准入控制器调用任何与请求匹配的变更 webhook。匹配的 webhook 将被串行调用。每一个 webhook 都可以根据需要修改对象。

>**谨慎编写和安装变更 webhook**，因为内建资源和第三方资源的控制环，未来可能会受到破坏性的更改，使现在运行良好的 Webhook 无法再正常运行。


- ValidatingAdmissionWebhook

>该准入控制器调用与请求匹配的所有验证 webhook。匹配的 webhook 将被并行调用。如果其中任何一个拒绝请求，则整个请求将失败。 该准入控制器仅在验证阶段运行；与 MutatingAdmissionWebhook 准入控制器所调用的 webhook 相反，它调用的 webhook 应该不会使对象出现变更。

- NamespaceExists

>该准入控制器检查除自身`Namespace`以外的命名空间资源上的所有请求。如果请求引用的命名空间不存在，则拒绝该请求。

- NamespaceLifecycle 

>该准入控制器禁止在一个正在被终止的`Namespace`中创建新对象，并确保使用不存在的`Namespace`的请求被拒绝。该准入控制器还会禁止删除三个系统保留的命名空间，即`default、kube-system 和 kube-public`

- NodeRestriction 

>该准入控制器限制了`kubelet`可以修改的`Node, Pod`对象。为了受到这个准入控制器的限制，kubelet 必须使用在`system:nodes`组中的凭证，并使用`system:node:<nodeName>`形式的用户名。这样，`kubelet`只可修改自己的`Node API`对象，只能修改绑定到节点本身的`Pod`对象。

- PodNodeSelector

>这个准入控制器通过读取命名空间注释和全局配置来限制什么节点选择器可以在一个命名空间中使用

- PodSecurityPolicy 

>此准入控制器负责在创建和修改`pod`时根据请求的安全上下文和可用的`pod`安全策略确定是否可以执行请求。

- PodTolerationRestriction 

>该准入控制器首先验证`Pod`的容忍度与其命名空间的容忍度之间的冲突。如果存在冲突，则拒绝`Pod`请求。如果`pod`的命名空间没有任何关联的默认容忍度或容忍度白名单，则使用集群级别的默认容忍度或容忍度白名单（如果有的话）。

- ServiceAccount

>该准入控制器实现了`serviceAccounts`的自动化。


#### 18.如何使用statefulset部署有状态应用？

**To Be Continue ~**

#### 参考文档

>`https://kubernetes.io/zh/docs/reference/access-authn-authz/admission-controllers/`

>`https://www.qikqiak.com/post/k8s-admission-webhook/`
