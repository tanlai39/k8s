## 1. Kiểm tra Deployment & Pod
# Deployment có lên đủ replica chưa
```
root@master-01:~# kubectl get deploy tpcoms01
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
tpcoms01   3/3     3            3           6m41s
```
# Xem chi tiết nếu có vấn đề
```
root@master-01:~# kubectl describe deploy tpcoms01
Name:                   tpcoms01
Namespace:              default
CreationTimestamp:      Fri, 21 Nov 2025 15:40:19 +0700
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=tpcoms
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=tpcoms
  Containers:
   tpcoms04:
    Image:         nginx
    Port:          80/TCP
    Host Port:     0/TCP
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   tpcoms01-859cc9859 (3/3 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  7m21s  deployment-controller  Scaled up replica set tpcoms01-859cc9859 from 0 to 3
```

# Pod có Running hết chưa
```
root@master-01:~# kubectl get pods -l app=tpcoms -o wide
NAME                       READY   STATUS    RESTARTS   AGE     IP              NODE        NOMINATED NODE   READINESS GATES
tpcoms01-859cc9859-4vkjr   1/1     Running   0          7m44s   192.168.0.76    worker-02   <none>           <none>
tpcoms01-859cc9859-5j5l6   1/1     Running   0          7m44s   192.168.0.196   worker-03   <none>           <none>
tpcoms01-859cc9859-r6bvz   1/1     Running   0          7m45s   192.168.0.5     worker-01   <none>           <none>
```

# Nếu pod nào lỗi thì xem log
```
root@master-01:~# kubectl logs tpcoms01-859cc9859-4vkjr
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2025/11/21 08:40:33 [notice] 1#1: using the "epoll" event method
2025/11/21 08:40:33 [notice] 1#1: nginx/1.29.3
2025/11/21 08:40:33 [notice] 1#1: built by gcc 14.2.0 (Debian 14.2.0-19)
2025/11/21 08:40:33 [notice] 1#1: OS: Linux 6.8.0-88-generic
2025/11/21 08:40:33 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:524288
2025/11/21 08:40:33 [notice] 1#1: start worker processes
2025/11/21 08:40:33 [notice] 1#1: start worker process 30
2025/11/21 08:40:33 [notice] 1#1: start worker process 31
```

## 2. Kiểm tra Service có “thấy” Pod không
# Service đã tạo đúng chưa
```
root@master-01:~# kubectl get svc tpcoms-service
NAME             TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
tpcoms-service   ClusterIP   10.101.3.67   <none>        80/TCP    8m34s
```


# Quan trọng nhất: Endpoints có IP pod không
```
root@master-01:~# kubectl get endpoints tpcoms-service -o wide
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME             ENDPOINTS                                         AGE
tpcoms-service   192.168.0.196:80,192.168.0.5:80,192.168.0.76:80   9m9s
```

## 3. Kiểm tra Ingress & Secret TLS
# Ingress đã tạo
```
root@master-01:~# kubectl get ingress tls-tpcoms-ingress
NAME                 CLASS   HOSTS         ADDRESS      PORTS     AGE
tls-tpcoms-ingress   nginx   tanlv.io.vn   10.0.0.200   80, 443   10m
```

# Xem chi tiết rule, backend, ingressClass
```
root@master-01:~# kubectl describe ingress tls-tpcoms-ingress
Name:             tls-tpcoms-ingress
Labels:           <none>
Namespace:        default
Address:          10.0.0.200
Ingress Class:    nginx
Default backend:  <default>
TLS:
  testsecret-tls terminates tanlv.io.vn
Rules:
  Host         Path  Backends
  ----         ----  --------
  tanlv.io.vn
               /   tpcoms-service:80 (192.168.0.5:80,192.168.0.76:80,192.168.0.196:80)
Annotations:   nginx.ingress.kubernetes.io/rewrite-target: /
Events:
  Type    Reason  Age                  From                      Message
  ----    ------  ----                 ----                      -------
  Normal  Sync    9m13s (x2 over 10m)  nginx-ingress-controller  Scheduled for sync
```











