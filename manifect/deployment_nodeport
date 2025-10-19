apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080    # có the de trong K8s tự chọn

Tóm tắt diễn giải của bạn (chuẩn rồi)

Deployment nginx-deploy
Tạo ra 3 Pod, mỗi Pod có 1 container chạy nginx mở port 80.
Dùng label app: nginx (ở dòng 11) để biết Pod nào là “con” của nó.
Khi Deployment tạo Pod, nó sẽ gắn label app: nginx (ở dòng 15).
Nếu label ở dòng 15 khác với dòng 11 → Pod vẫn được tạo, nhưng không được ReplicaSet/Deployment quản lý (nghĩa là chết thì không tự phục hồi).
nhản dòng 6 chỉ để “đặt nhãn” cho chính Deployment (nên giữ giống để dễ đọc).
18) chỉ là tên container, không liên quan đến label/selector.

```
root@master01:~# kubectl get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP              NODE       NOMINATED NODE   READINESS GATES
nginx-deploy-54b9c68f67-ggk8n   1/1     Running   0          2m15s   192.168.5.7     worker01   <none>           <none>
nginx-deploy-54b9c68f67-tjz9s   1/1     Running   0          2m15s   192.168.19.71   worker03   <none>           <none>
nginx-deploy-54b9c68f67-wwgbt   1/1     Running   0          2m15s   192.168.30.67   worker02   <none>           <none>
root@master01:~#
root@master01:~#
root@master01:~#
root@master01:~#
root@master01:~# kubectl get svc
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes      ClusterIP   10.96.0.1      <none>        443/TCP        52d
nginx-service   NodePort    10.99.93.158   <none>        80:30080/TCP   2m23s
```
