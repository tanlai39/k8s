
# Triển khai Kubernetes HA Cluster với 3 Master Node và nhiều Worker Node

**CNI:** Calico  
**Container Runtime:** containerd  
**Hệ điều hành:** Ubuntu 22.04+

---

## 1️⃣ Chuẩn bị trước

**Yêu cầu:**
- 3 Master Nodes và >=1 Worker Node
- Có thể SSH với quyền `root` hoặc `sudo`
- Các node kết nối mạng nội bộ với nhau (kết nối bằng IP và FQDN/Hostname)
- Swap đã tắt hoàn toàn
- Đồng bộ thời gian (NTP)
- trỏ DNS record tke-k8s về ip master-01
```
rm -rf /etc/netplan/50*
mv /etc/netplan/99* /etc/netplan/k8s.yaml
sudo systemctl restart systemd-resolved
sudo systemctl enable systemd-resolved
sudo ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo netplan apply
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
sudo apt install -y chrony
cat <<'EOF' | sudo tee /etc/chrony/chrony.conf
confdir /etc/chrony/conf.d
server 0.asia.pool.ntp.org iburst
sourcedir /run/chrony-dhcp
sourcedir /etc/chrony/sources.d
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
maxupdateskew 100.0
rtcsync
makestep 1 3
leapsectz right/UTC
EOF
sudo systemctl restart chrony
sudo systemctl enable chrony
sudo sed -i "2i 127.0.1.1 $HOSTNAME" /etc/hosts
sudo sed -i '3i ' /etc/hosts
sudo apt update -y && sudo apt upgrade -y
```

```
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/containerd.conf
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
```
---

## 2️⃣ Cài containerd và Kubernetes packages trên tất cả các node

**Thực hiện các bước sau trên từng node (Master & Worker):**

```bash
wget https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz -P /tmp/
sudo tar -C /usr/local -xzf /tmp/containerd-2.1.4-linux-amd64.tar.gz

sudo wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

wget https://github.com/opencontainers/runc/releases/download/v1.3.2/runc.amd64 -O /tmp/runc
sudo install -m 755 /tmp/runc /usr/local/sbin/runc

wget https://github.com/containernetworking/plugins/releases/download/v1.8.0/cni-plugins-linux-amd64-v1.8.0.tgz -P /tmp/
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf /tmp/cni-plugins-linux-amd64-v1.8.0.tgz

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

sudo apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo reboot
```

---

## 3️⃣ Khởi tạo Master node đầu tiên

```bash
# Bạn cần chuẩn bị:
# - Control Plane Endpoint (VD: 10.10.10.11:6443)
# - Pod Network CIDR (VD: 192.168.0.0/16)
# - Service CIDR (VD: 10.96.0.0/12)
# - Danh sách các SAN (DNS hoặc IP)
```

```bash
sudo kubeadm init \
  --pod-network-cidr "<POD_CIDR>" \
  --control-plane-endpoint "<ENDPOINT:PORT>" \
  --apiserver-cert-extra-sans "<SAN1>,<SAN2>,..." \
  --upload-certs
```

> Example:

```shell
kubeadm init \
--pod-network-cidr 192.168.0.0/16 \
--service-cidr 10.96.0.0/12 \
--control-plane-endpoint k8s-tke.tanlv.io.vn:6443 \
--apiserver-cert-extra-sans k8s-tke.k8s.local \
--apiserver-cert-extra-sans k8s-tke.tanlv.io.vn \
--apiserver-cert-extra-sans 10.0.0.10 \
--apiserver-cert-extra-sans control-plane-01 \
--apiserver-cert-extra-sans control-plane-02 \
--apiserver-cert-extra-sans control-plane-03 \
--apiserver-cert-extra-sans 10.0.0.11 \
--apiserver-cert-extra-sans 10.0.0.12 \
--apiserver-cert-extra-sans 10.0.0.13 \
--apiserver-cert-extra-sans 61.14.236.252 \
--upload-certs \
--dry-run
```

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 4️⃣ Cài Calico làm CNI plugin

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/tigera-operator.yaml
sleep 10
```
2 lệnh này chạy cách nhau 1 lúc

```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/custom-resources.yaml
```

---

## 5️⃣ Tạo lệnh join và chứng chỉ

```bash
kubeadm token create --print-join-command > /tmp/node-join-cmd
cp /tmp/node-join-cmd /tmp/master-join-cmd

CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | grep -E '^[a-f0-9]{64}$')
sed -i "s/\$/ --control-plane --certificate-key $CERT_KEY/" /tmp/master-join-cmd
```

```bash
mkdir -p /tmp/cluster-certs/etcd
chmod -R 777 /tmp/cluster-certs
cp /etc/kubernetes/pki/{ca.*,sa.*,front-proxy-ca.*} /tmp/cluster-certs/
cp /etc/kubernetes/pki/etcd/ca.* /tmp/cluster-certs/etcd
cp /tmp/master-join-cmd /tmp/node-join-cmd /tmp/cluster-certs/
```

```
sudo chown -R ubuntu:ubuntu /tmp/cluster-certs
```

---

## 6️⃣ Thêm các Master node còn lại

**Trên các master node 2 và 3:**

```bash
scp -r -i id_rsa ubuntu@<MASTER1_IP>:/tmp/cluster-certs ~/
sudo mkdir -p /etc/kubernetes/pki/etcd/
sudo cp ~/cluster-certs/*.crt ~/cluster-certs/*.key ~/cluster-certs/*.pub /etc/kubernetes/pki/
sudo cp ~/cluster-certs/etcd/ca.* /etc/kubernetes/pki/etcd/
```

> Run join command for master node

---

## 7️⃣ Thêm các Worker node

**Trên mỗi worker node:**

> Run join command for worker node

trỏ lại DNS record tke-k8s về lại IP VIP
---

## 8️⃣ Kiểm tra Cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

## 9 Cài INGRESS

deploy metallb:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/refs/heads/main/config/manifests/metallb-native.yaml
```

```
vi metallb-config.yaml
```

```
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.0.200-10.0.0.249  # Dải IP được chọn
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec: {}
```

```
kubectl apply -f metallb-config.yaml
```

cai Ingress Controller: dung helm

B1: caif helm
```
sudo snap install helm --classic
```
B2: Setup NGINX ingress by Helm
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```
## KIỂM TRA INGRESS

```
root@master-01:~# kubectl get pods -n ingress-nginx
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-645b679d5c-5vqr6   1/1     Running   0          3m51s
```

```
root@master-01:~# kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       3m15s
```

```
root@master-01:~# kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.99.236.43   10.0.0.200    80:32491/TCP,443:31001/TCP   2m36s
ingress-nginx-controller-admission   ClusterIP      10.97.97.188   <none>        443/TCP                      2m36s
```

## 9 Mount NFS

```
 wget https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/refs/heads/master/deploy/install-driver.sh
```

```
chmod +x install-driver.sh
./install-driver.sh
```

kiểm tra

```
root@master-01:~# kubectl -n kube-system get pods -l app=csi-nfs-controller -o wide
NAME                                  READY   STATUS    RESTARTS       AGE     IP          NODE        NOMINATED NODE   READINESS GATES
csi-nfs-controller-6994f688bc-dszlv   5/5     Running   1 (7m4s ago)   7m44s   10.0.0.23   worker-03   <none>           <none>
root@master-01:~#
root@master-01:~#
root@master-01:~# kubectl -n kube-system get pods -l app=csi-nfs-node -o wide
NAME                 READY   STATUS    RESTARTS   AGE     IP          NODE        NOMINATED NODE   READINESS GATES
csi-nfs-node-7jc9d   3/3     Running   0          7m55s   10.0.0.22   worker-02   <none>           <none>
csi-nfs-node-8m8qv   3/3     Running   0          7m55s   10.0.0.12   master-02   <none>           <none>
csi-nfs-node-bwgvf   3/3     Running   0          7m55s   10.0.0.21   worker-01   <none>           <none>
csi-nfs-node-c7ff5   3/3     Running   0          7m55s   10.0.0.11   master-01   <none>           <none>
csi-nfs-node-m8964   3/3     Running   0          7m55s   10.0.0.13   master-03   <none>           <none>
csi-nfs-node-xc4nr   3/3     Running   0          7m55s   10.0.0.23   worker-03   <none>           <none>
```

```
vi sc-nfs.yaml
```

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi-sc
provisioner: nfs.csi.k8s.io
parameters:
  server: 10.0.0.70     # ví dụ: 10.0.0.70
  share:  /data_k8s       # ví dụ: /data_k8s
mountOptions:
  - nfsvers=4.1
  - rsize=1048576
  - wsize=1048576
  - hard
  - timeo=600
  - retrans=2
reclaimPolicy: Delete        # xóa PVC sẽ xóa thư mục con trên share
volumeBindingMode: Immediate
```

```
vi pvc-pod-test.yaml
```

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-csi-pvc
spec:
  accessModes: ["ReadWriteMany"]          # điểm mạnh của NFS
  storageClassName: nfs-csi-sc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: nfs-csi-pod
spec:
  securityContext:
    fsGroup: 2000                         # giúp ghi nếu server dùng root_squash
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh","-c","id; touch /data/ok && echo hello > /data/hello.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nfs-csi-pvc
```


```
kubectl apply -f sc-nfs.yaml
kubectl apply -f pvc-pod-test.yaml
```

```
root@master-01:~# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-41de37a4-86ec-41c0-99fb-bef2e1db5e2a   5Gi        RWX            Delete           Bound    default/nfs-csi-pvc   nfs-csi-sc     <unset>                          147m
root@master-01:~#
root@master-01:~#
root@master-01:~# kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
nfs-csi-pvc   Bound    pvc-41de37a4-86ec-41c0-99fb-bef2e1db5e2a   5Gi        RWX            nfs-csi-sc     <unset>                 147m
root@master-01:~#
root@master-01:~#
root@master-01:~#
root@master-01:~# kubectl get pod
NAME          READY   STATUS    RESTARTS      AGE
nfs-csi-pod   1/1     Running   2 (27m ago)   148m
root@master-01:~#
```








