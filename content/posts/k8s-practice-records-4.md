---
title: "k8s实践记录（四）"
date: 2020-08-14T03:10:06Z
description:  "k8s实践记录（四）"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/4BA11CE3936F4EAF9351604931CAD8B1?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "practice"
---

### 16 如何对pod做权限限制？（认证、授权篇）

要想知道k8s如何对pod做权限限制，首先我们得知道pod是怎么访问k8s集群的资源的。

由于k8s本身是没有提供用户管理能力的，所以只要“用户”（非linux用户）持有**kubeconfig凭据**或者服务（如pod）具有访问集群资源的**ServiceAccount**，经过k8s**认证流程**之后，api-server 就会将请求凭证中的用户身份转化为对应的`user`和`groups`这样的**用户模型**，使用这个用户模型通过**鉴权流程**和**准入控制流程**就可以访问api-server中有权限访问的资源。

上面提到的k8s访问请求流程具体可以分为**认证authentication**（是否为集群合法用户）、**鉴权authorization**（用户是否有权限操作所请求的资源）、**准入控制admissioncontrol**（请求是否安全合规）、持久化数据到etcd这几个步骤。

而集群资源访问控制的两种方式，使用**kubeconfig凭据**和使用**serviceaccount**就是这次实践内容。而k8s对pod做权限限制使用的就是`serviceaccount`的方式。

#### 一、第一种访问方式：使用kubeconfig凭据方式访问集群

先看使用kubeconfig的方式，k8s使用证书请求资源的认证方式基本都是**X509证书认证**，访问者通常会使用由集群 CA 签发的客户端证书config去访问api-server。**这种方式通常是用户本地连接k8s集群使用的方式。pod使用的就是`serviceaccount`的方式。**

**X509证书认证的证书**由放在集群master节点的`/etc/kubernetes/pki/`目录下的公钥`ca.crt`和私钥`ca.key`来签发，那**证书如何签发**呢，k8s提供了个签发的api`certificates.k8s.io/v1beta1`

#### **第一种访问方式实践**

比如现在我要创建一个‘用户’`vickey`来访问集群的资源，首先要创建一个**证书签名请求CSR certificate signing request**和一个私钥。

```
[root@master-1 yamlfiles]# openssl req -new -newkey rsa:4096 -nodes -keyout vickey.key -out vickey.csr -subj "/CN=vickey/O=dev"
Generating a 4096 bit RSA private key
..........................................++
.........++
writing new private key to 'vickey.key'
-----
[root@master-1 yamlfiles]# ls vickey.*
vickey.csr  vickey.key
```

然后用生成的证书**签名请求csr**文件创建一个k8s对象`csr`，在未被有权限的管理员审批`approve`之前会处于`pending`状态，只有审批后状态才会变成`Approved,Issued`。

```
[root@master-1 yamlfiles]# kubectl get csr --all-namespaces 
No resources found

[root@master-1 yamlfiles]# cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: vickey-access-test
spec:
  request: $(cat vickey.csr | base64 | tr -d '\n')
  usages:
  - client auth
EOF


certificatesigningrequest.certificates.k8s.io/vickey-access-test created
[root@master-1 yamlfiles]# ls vickey.*
vickey.csr  vickey.key
[root@master-1 yamlfiles]# kubectl  get csr
NAME                 AGE   REQUESTOR          CONDITION
vickey-access-test   14s   kubernetes-admin   Pending


[root@master-1 yamlfiles]# kubectl certificate approve vickey-access-test
certificatesigningrequest.certificates.k8s.io/vickey-access-test approved
[root@master-1 yamlfiles]# kubectl  get csr
NAME                 AGE     REQUESTOR          CONDITION
vickey-access-test   8m15s   kubernetes-admin   Approved,Issued
```

将已签名的证书内容持久化到`.crt`文件中

```
[root@master-1 yamlfiles]# kubectl get csr vickey-access-test -o jsonpath='{.status.certificate}' | base64 --decode > vickey-access-test.crt
[root@master-1 yamlfiles]# cat vickey-access-test.crt 
-----BEGIN CERTIFICATE-----
MIIEBjCCAu6gAwIBAgIUbSNC1co5FiJ4rUd3zN15ITBLQxYwDQYJKoZIhvcNAQEL
......
d2xAmipqTuhqnjLbx+OZDsMjuTktiAXA+OHZcF/JjpLP5xjibbfYwkziLZEiuPON
usiDR2nUKLeCEp2CcJG/1/hzCrQNnuVQrgc=
-----END CERTIFICATE-----
```

有了签名证书还需要**集群的`ca.crt`证书**，因为下面配置集群权限需要用到。可以直接从`/etc/kubernetes/pki/ca.crt`复制一份过来，因为`kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode - > k8s-cluster-ca.crt`获取的就是`ca.crt`的内容。

```
[root@master-1 yamlfiles]# kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --raw | base64 --decode - > k8s-cluster-ca.crt
[root@master-1 yamlfiles]# cat k8s-cluster-ca.crt 
-----BEGIN CERTIFICATE-----
MIICyDCCAbCgAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
......
4IzuQQRMTa7QqzyHCYlbp6Sb7YFxkwcwfMbLpqlUPWGDFGqepnKFp5aHhd0=
-----END CERTIFICATE-----

[root@master-1 yamlfiles]# diff k8s-cluster-ca.crt /etc/kubernetes/pki/ca.crt
[root@master-1 yamlfiles]#
```

因为`kubeconfig`是用户本地连接k8s集群使用的重要访问凭证，使用kubeconfig凭据方式访问集群最关键的一步就是**生成config凭据**，它是一个包含‘用户’已被签名的证书、集群的ca证书等信息的证书。这个生成凭据过程又细分为3步。


第一步：设置连接集群的必要信息（集群名，集群url）并写入到用来连接集群的访问凭据`vickey-config`中。

```
[root@master-1 yamlfiles]# kubectl config set-cluster $(kubectl config view -o jsonpath='{.clusters[0].name}') --server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}') --certificate-authority=k8s-cluster-ca.crt --kubeconfig=vickey-config --embed-certs=true
Cluster "kubernetes" set.

[root@master-1 yamlfiles]# cat vickey-config 
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1......BVEUtLS0tLQo=
    server: https://192.168.229.130:6443
  name: kubernetes
contexts: []
current-context: ""
kind: Config
preferences: {}
users: []
```

第二步：设置“用户”凭据名、将“用户”的证书和秘钥导入到访问凭据`vickey-config`中

```
[root@master-1 yamlfiles]# kubectl config set-credentials vickey --client-certificate=vickey-access-test.crt --client-key=vickey.key --embed-certs --kubeconfig=vickey-config
User "vickey" set.
```
```
[root@master-1 yamlfiles]# cat vickey-config 
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1......BVEUtLS0tLQo=
    server: https://192.168.229.130:6443
  name: kubernetes
contexts: []
current-context: ""
kind: Config
preferences: {}
users:
- name: vickey
  user:
    client-certificate-data: LS0tLS1CRUdJ.......FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJ.......RSBLRVktLS0tLQo=
```

第三步：为“用户”设置访问集群的上下文，名为`vickey`，能访问的域名空间为集群的`default`，同样将信息写入到访问凭据`vickey-config`中。

```
[root@master-1 yamlfiles]# kubectl config set-context vickey --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') --namespace=default --user=vickey --kubeconfig=vickey-config
Context "vickey" created.
```
```
[root@master-1 yamlfiles]# cat vickey-config 
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1......BVEUtLS0tLQo=
    server: https://192.168.229.130:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: default
    user: vickey
  name: vickey
current-context: ""
kind: Config
preferences: {}
users:
- name: vickey
  user:
    client-certificate-data: LS0tLS1CRUdJ.......FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJ.......RSBLRVktLS0tLQo=
```

至此使用kube-config凭据方式访问集群所需的信息都已大工高成，接下来使用生成的凭据`vickey-config`测试一下。先切换一下上下文，然后用凭据访问`default`域名空间的pod资源，报错说`vickey`无法list域名空间default的资源pods。

```
[root@master-1 yamlfiles]# kubectl config use-context vickey --kubeconfig=vickey-config
Switched to context "vickey".

[root@master-1 yamlfiles]# kubectl  get pod --kubeconfig=vickey-config
Error from server (Forbidden): pods is forbidden: User "vickey" cannot list resource "pods" in API group "" in the namespace "default": RBAC: clusterrole.rbac.authorization.k8s.io "test-role" not found
```

就像最开始所说的，访问集群最终还是要转化为对应的`user`和`groups`这样的**用户模型**来访问集群的，所以得给‘用户’vickey加一个预置的角色才行，即clusterrole中预置的角色，不同角色对应着不同的访问集群资源权限，view只能查看pod等资源，admin能删除创建pod等资源

```
[root@master-1 yamlfiles]# kubectl  get clusterrole
NAME                                                                   AGE
admin                                                                  65d
cluster-admin                                                          65d
edit                                                                   65d
flannel                                                                65d
system:aggregate-to-admin                                              65d
system:aggregate-to-edit                                               65d
system:aggregate-to-view                                               65d
......
view                                                                   65d
```

下面将‘用户’vickey与`clusterrole`角色`view`绑定，创建一个集群对象`rolebinding`来，它只能查看访问空间为`default`的资源，不能删除，创建资源等。

```
[root@master-1 yamlfiles]# kubectl create rolebinding vickey-view --namespace=default --clusterrole=view --user=vickey
rolebinding.rbac.authorization.k8s.io/vickey-view created
[root@master-1 yamlfiles]# kubectl  get pod --kubeconfig=vickey-config
NAME                                  READY   STATUS    RESTARTS   AGE
test-configmap-pod-674dc6685c-b24vl   2/2     Running   0          103s
[root@master-1 yamlfiles]# kubectl  delete pod test-configmap-pod-674dc6685c-b24vl --kubeconfig=vickey-config
Error from server (Forbidden): pods "test-configmap-pod-674dc6685c-b24vl" is forbidden: User "vickey" cannot delete resource "pods" in API group "" in the namespace "default": RBAC: clusterrole.rbac.authorization.k8s.io "test-role" not found
```

将‘用户’vickey与`clusterrole`角色`admin`绑定，创建一个集群对象`rolebinding`来，它就能操作空间为`default`的所有资源了，但仅限于`default`空间，其他空间资源（如下面的`test`）也是不能删除，创建的。

```
[root@master-1 yamlfiles]# kubectl create rolebinding vickey-admin --namespace=default --clusterrole=admin --user=vickey
rolebinding.rbac.authorization.k8s.io/vickey-admin created
[root@master-1 yamlfiles]# kubectl  get pod --kubeconfig=vickey-config
NAME                                  READY   STATUS    RESTARTS   AGE
test-configmap-pod-674dc6685c-qd8xc   2/2     Running   0          40h

[root@master-1 yamlfiles]# kubectl get pod -n test --kubeconfig=vickey-config
Error from server (Forbidden): pods is forbidden: User "vickey" cannot list resource "pods" in API group "" in the namespace "test"
```

绑定角色为`admin`的权限具体可以使用`kubectl get clusterrole admin -o yaml`查看，其中`rules`下面的`resources`就是有权限操作的资源，`verbs`就是对应资源的访问权限。

```
[root@master-1 ~]# kubectl get clusterrole admin -o yaml
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.authorization.k8s.io/aggregate-to-admin: "true"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2020-06-09T02:25:46Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: admin
  resourceVersion: "320"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterroles/admin
  uid: 378a73fa-1a00-49b3-b9a5-a168ded5c507
rules:
- apiGroups:
  - ""
  resources:
  - pods/attach
  - pods/exec
  - pods/portforward
  - pods/proxy
  - secrets
  - services/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  ......
- apiGroups:
  ......
```

至此，第一种使用kube-config凭据方式访问集群基本流程就是这样，下面看看第二种访问集群的方式。

#### 二、第二种访问方式：使用ServiceAccount访问集群

pod应用基本都是使用ServiceAccount访问集群，在访问时pod会自动绑定一个签名后的JWT(JSON Web Tokens) 去请求集群api-server，而Service Account就是其中一种token，这个token里面包含了访问集群需要的签发者、用户的身份、过期时间等多种元信息，有了这些信息就可以通过认证、鉴权、准入控制等流程了，最终全部通过就可以访问集群了。

- 相比第一种方式，**ServiceAccount**是k8s以**api的方式管理访问api-server的凭据**，也是唯一一个。

- 这种方式通常用于pod中的业务进程与api-server交互
- 当创建一个namespace后会同时在该namespace下生成名为`default`的ServeiceAccount和挂载类型为service-account-token用的secret以方便pod需要访问集群资源时用到。但这个名为`default`的`serviceaccount`默认不具有任何权限。

```
[root@master-1 yamlfiles]# kubectl  get serviceaccounts default -o yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2020-06-09T02:26:05Z"
  name: default
  namespace: default
  resourceVersion: "336"
  selfLink: /api/v1/namespaces/default/serviceaccounts/default
  uid: 8d2f0fa4-f990-4839-a330-c43a83855e87
secrets:
- name: default-token-csk5t
```

挂载类型为service-account-token用的secret，这里的ca.crt经过base64解码就可看到它就是集群证书`/etc/kubernetes/pki/ca.crt`。

```
[root@master-1 yamlfiles]# kubectl get secrets default-token-csk5t -o yaml
apiVersion: v1
data:
  ca.crt: LS0tLS1CRU......NBVEUtLS0tLQo=
  namespace: ZGVmYXVsdA==
  token: ZXlKaGJHY......THRBdEI2VWhn
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: default
    kubernetes.io/service-account.uid: 8d2f0fa4-f990-4839-a330-c43a83855e87
  creationTimestamp: "2020-06-09T02:26:05Z"
  name: default-token-csk5t
  namespace: default
  resourceVersion: "333"
  selfLink: /api/v1/namespaces/default/secrets/default-token-csk5t
  uid: 2918a5f6-2e36-43df-ad95-16f117473f70
type: kubernetes.io/service-account-token
```

名为`default`的`serviceaccount`默认不具有任何权限，访问`svc, pod`等都是`403`的

```
[root@master-1 ~]# kubectl run -i --tty --rm curl --image=radial/busyboxplus:curl
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
If you don't see a command prompt, try pressing enter.
[ root@curl-69c656fd45-2fghj:/ ]$ CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
[ root@curl-69c656fd45-2fghj:/ ]$ TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
[ root@curl-69c656fd45-2fghj:/ ]$ NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
[ root@curl-69c656fd45-2fghj:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/$NAMESPACE/services/"
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {
    
  },
  "status": "Failure",
  "message": "services is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"services\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "services"
  },
  "code": 403
  
[ root@curl-69c656fd45-2fghj:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/$NAMESPACE/pods/"
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {
    
  },
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
```

要想`pod`能够访问集群资源就得跟第一种方式一样给默认生成的名为`default`的`serviceaccount`赋予一个有权限访问的角色`role`才行。下面创建了一个`test-role`的角色，能够`get, watch, list`域名空间`default`的资源`pods`。

```
[root@master-1 yamlfiles]# cat test-role.yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-role
  namespace: default
rules:
- apiGroups: [""] # "" 指定核心 API 组
  resources: ["pods", "services"]
  verbs: ["get", "watch", "list"]
```

然后将有权限的角色`test-role`与默认创建名为`default`的`serviceaccount`用`RoleBinding`绑定，`subjects`可以是`user, group, serviceaccount`，注意：不能修改已创建的`rolebinding`，修改后apply会报错，只能删除重新创建。

```
[root@master-1 yamlfiles]# cat test-rolebinding.yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test-rolebinding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: test-role
subjects:
  #- kind: User
  #- kind: Group
  - kind: ServiceAccount
    name: default
    namespace: default
```

创建`role和rolebinding`后就可以访问之前不能访问的`services, pod`资源了。

```
[ root@curl-69c656fd45-2fghj:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/$NAMESPACE/services/"
{
  "kind": "ServiceList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/default/services/",
    "resourceVersion": "579968"
  },
  "items": [
    {
      {
      ......
      },
      "spec": {
        "ports": [
          {
            "name": "https",
            "protocol": "TCP",
            "port": 443,
            "targetPort": 6443
          }
        ],
        "clusterIP": "10.96.0.1",
        "type": "ClusterIP",
        "sessionAffinity": "None"
      },
      "status": {
        "loadBalancer": {
          
        }
      }
    },
    ......
   ]
}
```
```
[ root@curl-69c656fd45-2fghj:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/$NAMESPACE/pods/"
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/default/pods/",
    "resourceVersion": "586324"
  },
  "items": [
            ......
            "ready": true,
            "restartCount": 2,
            "image": "redis:latest",
            "imageID": "docker-pullable://redis@sha256:09c33840ec47815dc0351f1eca3befe741d7105b3e95bc8fdb9a7e4985b9e1e5",
            "containerID": "docker://5f8ec1b06a7eacff0c2d38bb2c9c6cd2654d064e70da38012d866ad9d151c980",
            "started": true
          }
        ],
        "qosClass": "BestEffort"
      }
    }
  ]
}
```

但是`role`角色仅对特定域名空间有效，这里仅对`default namespace`有效，所以要对其他域名空间是访问不了的。如下访问`kube-system`的`svc, pod`资源就`403`了。

```
[ root@curl-tns-794f864c5c-bphsl:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/kube-system/pods/"
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {
    
  },
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"kube-system\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403

[ root@curl-tns-794f864c5c-bphsl:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/kube-system/services/"
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {
    
  },
  "status": "Failure",
  "message": "services is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"services\" in API group \"\" in the namespace \"kube-system\"",
  "reason": "Forbidden",
  "details": {
    "kind": "services"
  },
  "code": 403
```

那要使默认`serviceaccount`能`default`能访问其他域名空间的资源就得赋予一个`clusterrole`并且将它们绑定才行了。
```
[root@master-1 yamlfiles]# cat test-clusterrole.yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-clusterrole
  #namespace: default
rules:
- apiGroups: [""] # "" 指定核心 API 组
  resources: ["pods", "services"]
  verbs: ["get", "watch", "list"]


[root@master-1 yamlfiles]# cat test-clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: test-clusterrole
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default


[root@master-1 yamlfiles]# kubectl apply -f test-clusterrole.yaml 
clusterrole.rbac.authorization.k8s.io/test-clusterrole created
[root@master-1 yamlfiles]# kubectl apply -f test-clusterrolebinding.yaml 
clusterrolebinding.rbac.authorization.k8s.io/test-clusterrolebinding created
[root@master-1 yamlfiles]# kubectl get clusterrole test-clusterrole 
NAME               AGE
test-clusterrole   16s
[root@master-1 yamlfiles]# kubectl get clusterrolebindings.rbac.authorization.k8s.io test-clusterrolebinding 
NAME                      AGE
test-clusterrolebinding   22s
```

可以看到现在已经可以正常访问域名空间为`kube-system`的`services, pods`了。

```
[ root@curl-tns-794f864c5c-bphsl:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/kube-system/services/"
{
  "kind": "ServiceList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/kube-system/services/",
    "resourceVersion": "610563"
  },
  "items": [
  ......
  ]
}
```
```
[ root@curl-tns-794f864c5c-bphsl:/ ]$ curl --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces/kube-system/services/"
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/kube-system/pods/",
    "resourceVersion": "610739"
  },
  "items": [
  ......
  ]
}
```

由上面可知，其实`ServiceAccount api`就是将第一种方式生成签名证书等复杂步骤给搞定了，当调用api时就**自动生成一个default-token（里面包含了集群的ca.crt证书）来作为签名证书，自动生成一个名为`default`的`serviceaccount`，但它没有任何访问集群资源的权限，如果需要权限的话得给它绑定一个`role(clusterrole)`，然后只要有了这个具有权限的`serviceaccount`的`pod`就可以正常访问集群了**。

#### 小结

至此，此篇记录已大概实践了下`api-server`访问流程中的**认证流程**，**鉴权流程**，下一篇实践下**准入控制流程**

#### 参考文章
>`https://developer.aliyun.com/lesson_1651_18376?spm=5176.10731542.0.0.3c0b20belXDiuY#_18376`

>`https://www.openlogic.com/blog/granting-user-access-your-kubernetes-cluster`

>`https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/`

>`https://kubernetes.io/docs/reference/access-authn-authz/rbac/`

>`https://thenewstack.io/kubernetes-access-control-exploring-service-accounts/`

### 17.如何对pod做权限限制？(准入控制篇)

**To Be Continue ~**
