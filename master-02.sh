#!/usr/bin/env bash

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
        - 10.0.0.112/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        search:
          - k8s.local
        addresses:
          - 10.0.0.250
EOF

systemctl enable --now systemd-resolved
ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf

hostnamectl set-hostname control-plane-10.k8s.local
echo "127.0.1.1 control-plane-10.k8s.local" >> /etc/hosts
timedatectl set-timezone Asia/Ho_Chi_Minh

echo "[INFO] Waiting for network..."
for i in {1..30}; do
  ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && break
  sleep 2
done

# ---------------- TIME ----------------
echo "[INFO] network OK, Waitting 2 phut lam tiep"
sleep 120
apt update -y
apt upgrade -y
apt-get install -y chrony
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

  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  touch /var/lib/k8s/step1.done
fi

# ================= STEP 2 =================
if [ ! -f /var/lib/k8s/step2.done ]; then
  echo "[INFO] STEP 2 running..."
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  cat > /root/.ssh/id_ed25519 <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACD1xpT/7fwsfIZDcX3Fqt4qWKjhyY4Ubnmr/kqd262+CgAAAJjN0oDUzdKA
1AAAAAtzc2gtZWQyNTUxOQAAACD1xpT/7fwsfIZDcX3Fqt4qWKjhyY4Ubnmr/kqd262+Cg
AAAEDd+pDjXvzKfNkHxNgQrGPjhXTdkPkd2hpM4EEACzdCrvXGlP/t/Cx8hkNxfcWq3ipY
qOHJjhRueav+Sp3brb4KAAAAEXRhbi5sYWlAdHBjb21zLnZuAQIDBA==A
-----END OPENSSH PRIVATE KEY-----
EOF

  chmod 600 /root/.ssh/id_ed25519
  chown root:root /root/.ssh/id_ed25519

  rm -rf /root/cluster-certs
  mkdir -p /root/cluster-certs

  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /root/.ssh/id_ed25519 -r ubuntu@10.0.0.111:/tmp/cluster-certs /root/ || {
    echo "[ERROR] scp certs failed"
    exit 1
  }
  sudo mkdir -p /etc/kubernetes/pki/etcd/
  sudo cp ~/cluster-certs/*.crt ~/cluster-certs/*.key ~/cluster-certs/*.pub /etc/kubernetes/pki/
  sudo cp ~/cluster-certs/etcd/ca.* /etc/kubernetes/pki/etcd/
  sudo mv /root/cluster-certs/node-join-cmd /root/cluster-certs/node-join-cmd.sh
  sudo mv /root/cluster-certs/master-join-cmd /root/cluster-certs/master-join-cmd.sh
  sudo bash /root/cluster-certs/master-join-cmd.sh

  touch /var/lib/k8s/step2.done
fi

echo "[INFO] build-k8s.sh finished at $(date)"
