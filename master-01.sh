#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/build-k8s.log
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] build-k8s.sh started at $(date)"
mkdir -p /var/lib/k8s
rm -rf /etc/netplan/*

cat > /etc/netplan/k8s.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      dhcp6: false
      addresses:
        - 10.0.0.111/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        search:
          - k8s.local
        addresses:
          - 10.0.0.250
EOF

netplan apply

systemctl enable --now systemd-resolved
ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf

hostnamectl set-hostname control-plane-09.k8s.local
echo "127.0.1.1 control-plane-09.k8s.local" >> /etc/hosts
timedatectl set-timezone Asia/Ho_Chi_Minh

echo "[INFO] Waiting for network..."
for i in {1..30}; do
  ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && break
  sleep 2
done

# ---------------- TIME ----------------
apt update -y
apt upgrade -y
apt install -y chrony
systemctl enable --now chrony

cat > /etc/chrony/chrony.conf <<'EOF'
server 0.asia.pool.ntp.org iburst
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
EOF

systemctl restart chrony

# ================= STEP 1 =================
if [ ! -f /var/lib/k8s/step1.done ]; then
  echo "[INFO] STEP 1 running..."

  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab

  printf "overlay\nbr_netfilter\n" > /etc/modules-load.d/containerd.conf
  modprobe overlay
  modprobe br_netfilter

  cat > /etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system

  wget -q https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz -P /tmp
  tar -C /usr/local -xzf /tmp/containerd-2.1.4-linux-amd64.tar.gz
  wget -q https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
    -O /etc/systemd/system/containerd.service
  systemctl daemon-reload
  systemctl enable --now containerd

  wget -q https://github.com/opencontainers/runc/releases/download/v1.3.2/runc.amd64 -O /usr/local/sbin/runc
  chmod +x /usr/local/sbin/runc

  wget -q https://github.com/containernetworking/plugins/releases/download/v1.8.0/cni-plugins-linux-amd64-v1.8.0.tgz -P /tmp
  mkdir -p /opt/cni/bin
  tar -C /opt/cni/bin -xzf /tmp/cni-plugins-linux-amd64-v1.8.0.tgz

  mkdir -p /etc/containerd
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd

  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list

  apt update
  apt install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  touch /var/lib/k8s/step1.done
  reboot
fi

# ================= STEP 2 =================
if [ ! -f /var/lib/k8s/step2.done ]; then
  echo "[INFO] STEP 2 running..."

  kubeadm init \
    --pod-network-cidr 192.168.0.0/16 \
    --service-cidr 10.96.0.0/12 \
    --control-plane-endpoint tke.tanlv.io.vn:6443 \
    --apiserver-cert-extra-sans tke.k8s.local \
    --apiserver-cert-extra-sans tke.tanlv.io.vn \
    --apiserver-cert-extra-sans 10.0.0.111 \
    --apiserver-cert-extra-sans control-plane-09 \
    --apiserver-cert-extra-sans 61.14.236.233 \
    --upload-certs

  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  echo "[INFO] Waiting for Kubernetes API..."
  for i in {1..60}; do
    if KUBECONFIG=/root/.kube/config kubectl get --raw=/healthz >/dev/null 2>&1; then
      echo "[INFO] API server is ready"
      break
    fi
    sleep 5
  done

  # Apply overlay networking (Calico)
  echo "[INFO] Applying Calico..."
  KUBECONFIG=/root/.kube/config kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/tigera-operator.yaml
  sleep 60
  KUBECONFIG=/root/.kube/config kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/custom-resources.yaml

  # ---------------------------------------------------------------------
  # NEW: WAIT NODE READY (SAU KHI APPLY CALICO)
  # ---------------------------------------------------------------------
  echo "[INFO] Waiting for node to become Ready (after CNI applied)..."
  for i in {1..90}; do
    READY_NODE=$(KUBECONFIG=/root/.kube/config kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{print $1}')
    if [ -n "$READY_NODE" ]; then
      echo "[INFO] Node Ready: $READY_NODE"
      break
    fi
    echo "[INFO] Node not Ready yet, retrying..."
    sleep 10
   done

   # ---------------------------------------------------------------------
   # NEW: EXPORT JOIN COMMAND + CERTS (SAU KHI NODE READY)
   # ---------------------------------------------------------------------
   echo "[INFO] Exporting join commands + certs..."
   mkdir -p /tmp/cluster-certs/etcd

   kubeadm token create --print-join-command > /tmp/node-join-cmd
   cp /tmp/node-join-cmd /tmp/master-join-cmd

   CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | grep -E '^[a-f0-9]{64}$' || true)
   if [ -n "$CERT_KEY" ]; then
     sed -i "s/$/ --control-plane --certificate-key $CERT_KEY/" /tmp/master-join-cmd
     echo "[INFO] Control-plane join command generated"
   else
     echo "[WARN] Certificate key not generated; master join may be incomplete"
 fi

   cp /etc/kubernetes/pki/{ca.*,sa.*,front-proxy-ca.*} /tmp/cluster-certs/ 2>/dev/null
   cp /etc/kubernetes/pki/etcd/ca.* /tmp/cluster-certs/etcd 2>/dev/null
   cp /tmp/node-join-cmd /tmp/master-join-cmd /tmp/cluster-certs/ 2>/dev/null

   chmod -R 755 /tmp/cluster-certs
   chown -R ubuntu:ubuntu /tmp/cluster-certs || true

   touch /var/lib/k8s/step2.done
fi

echo "[INFO] build-k8s.sh finished at $(date)"
