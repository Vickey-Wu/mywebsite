---
title: "部署k8s dashboard"
date: 2020-06-12T03:10:06Z
description:  "部署k8s dashboard"
type: "post"
image: "https://note.youdao.com/yws/api/personal/file/13828E91A7E445D8B2398E5CACE7D4D2?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a"
categories:
  - "k8s"
tags:
  - "k8s"
  - "dashboard"
---

#### dashboard的yaml文件

>`https://github.com/kubernetes/dashboard/blob/master/aio/deploy/recommended.yaml`


```
[root@master-1 ~]# kubectl apply -f dashboard.yaml 
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created
```

#### 访问dashboard

1. 使用代理访问dashboard

```
[root@master-1 ~]# kubectl proxy --address='192.168.229.130' --port=8080 --accept-hosts='^*$'
Starting to serve on 192.168.229.130:8080

```

浏览器访问，发现没有https它不给你登录。

```
https://192.168.229.130:8080/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

2. 改用`NodePort`来访问dashbaord

执行`edit`命令修改`type: ClusterIP `为`type: NodePort`，保存退出，看到暴露了`32716`端口

```
[root@master-1 dashboard]# kubectl -n kubernetes-dashboard edit service kubernetes-dashboard 
service/kubernetes-dashboard edited
[root@master-1 dashboard]# kubectl get svc --all-namespaces 
NAMESPACE              NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
kubernetes-dashboard   kubernetes-dashboard        NodePort    10.102.38.242   <none>        443:32716/TCP            127m

  ports:
  - nodePort: 32716
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  sessionAffinity: None
  type: NodePort
```

浏览器访问`ip:port`即可，即`https://192.168.229.130:32716/`，选择登录方式为`Token`，输入下面获取到的`token`值

```
[root@master-1 dashboard]# kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep kubernetes-dashboard | awk '{print $1}')
...
Data
====
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IjhsN2lfbGl4aGFHbUhKRFM0ME50N1cxVXMwU2Z2a0dIR29mS3FVWmJPbnMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC10b2tlbi1zenM2MiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjJjMDkxZTBlLTU3ODQtNDc4ZC04ZDU4LTJiOTVjODc3NGI5OSIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDprdWJlcm5ldGVzLWRhc2hib2FyZCJ9.Ngyr8OmmhoQOCxCiKYHPtzUC8Pp-U7jCdyjGeEGQ8hZlozpUtqlct95xxMioPJU9OOrdE_z4YlI1sQgLrD8OBLhOyXQ8yFExh1SIEx_FIJ9LQmtQ66JIpEt_WpeyXlH9tGYSjzYty14KvDMuO6EJodNEYwQo_L6-yRPvuhD0pX-P3X9P8yswa87ft2oD0-i90WABjopzr_JX4VWifPGcc8OX8LDg5NqDLU-qdYASiHGT3HgCdcTXP4mUVL5qC_oB_rHw83rnJxSMlYbgBBD0FwutaW5a1tsjb7FrycndvuLF9tEiIsNxeUoewK7mfeLoefyXu6CeIIQqqAMkEklvlA
```

登录成功，但发现啥都看不到，因为默认的用户`kubernetes-dashboard`没有权限

![](https://note.youdao.com/yws/api/personal/file/6F06790FA61847BD97CA1CEAD73C55BD?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a)

所以还要创建一个有权限的用户才能访问，将文档的内容复制下来再执行，然后再用这个新建的用户的`token`登录即可。

>`https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md`

```
[root@master-1 dashboard]# kubectl apply -f  copy-from-doc.yaml 
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user created

[root@master-1 dashboard]# kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
...
Data
====
ca.crt:     1025 bytes
namespace:  20 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IjhsN2lfbGl4aGFHbUhKRFM0ME50N1cxVXMwU2Z2a0dIR29mS3FVWmJPbnMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLW16d3dtIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlMGIxNTU1Yy03NGE1LTRkNDgtODI3Ni00ZGQzYzNhNTU4NjIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6YWRtaW4tdXNlciJ9.rXoZNAeQShpcEc5h-sMhnPyWwTsgdVXiJgcwmfkuFOCTE1JqAorwez52J1Xs-hhhNuExziGWf6YiKdV_3mp7v2qA9xreWQjikPpac3jfxHzZ-2aFpNxfK9ySfm1smxNU4XY1lqsnwUaHku4RyI2ZaL1J_85Tai86O2bVT0nkahp8xSMFUHGl89kOlzy2HFyyRYmIJLq__332axl1pwl9xIK887zJjo5kbeCeWIG-bBPQfmrGqsK2R7eHD2d15tEA8jzSYwYX9DfhN03Pvk6_hRPatzfyxUxSh8KZnKF2d_jrrWTY67hu_FucoJ2ZsPIFC2Fix85Ib2fkusj6sKz8Iw
```

然后部署个`nginx`看看，如图看到正在创建`pod`。`dashboard`可以看到集群的各种资源信息，也可以在`dashboard`里面创建各种资源，具体就之后慢慢去探索了。To Be Continue

![](https://note.youdao.com/yws/api/personal/file/94605C07D76A470D85BF28D46E0BAFBC?method=download&shareKey=10e1d28d2d230f120165cb901aa3ea1a)
