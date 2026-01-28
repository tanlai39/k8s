#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/build-k8s.log
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] build-k8s.sh started at $(date)"

mkdir -p /var/lib/k8s

###############################################################################
# STEP 1 – INSTALL CONTAINERD + K8S
###############################################################################
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
  reboot
fi

###############################################################################
# STEP 2 – JOIN CLUSTER
###############################################################################
if [ ! -f /var/lib/k8s/step2.done ]; then
  echo "[INFO] STEP 2 running..."

  # ---- SSH KEY ----
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh

  cat > /root/.ssh/id_ed25519 <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACD1xpT/7fwsfIZDcX3Fqt4qWKjhyY4Ubnmr/kqd262+CgAAAJjN0oDUzdKA
1AAAAAtzc2gtZWQyNTUxOQAAACD1xpT/7fwsfIZDcX3Fqt4qWKjhyY4Ubnmr/kqd262+Cg
AAAEDd+pDjXvzKfNkHxNgQrGPjhXTdkPkd2hpM4EEACzdCrvXGlP/t/Cx8hkNxfcWq3ipY
qOHJjhRueav+Sp3brb4KAAAAEXRhbi5sYWlAdHBjb21zLnZuAQIDBA==
-----END OPENSSH PRIVATE KEY-----
EOF

  chmod 600 /root/.ssh/id_ed25519

  # ---- WAIT CONTAINERD SOCKET ----
  echo "[INFO] Waiting for containerd socket..."
  for i in {1..60}; do
    if [ -S /var/run/containerd/containerd.sock ]; then
      echo "[INFO] containerd socket ready"
      break
    fi
    sleep 2
  done

  # ---- COPY JOIN FILE ----
  rm -rf /root/cluster-certs
  mkdir -p /root/cluster-certs

  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i /root/.ssh/id_ed25519 \
    -r ubuntu@10.0.0.111:/tmp/cluster-certs /root/ || {
      echo "[ERROR] scp certs failed"
      exit 1
    }

  mv /root/cluster-certs/node-join-cmd /root/cluster-certs/node-join-cmd.sh
  chmod +x /root/cluster-certs/node-join-cmd.sh

  # ---- JOIN ----
  echo "[INFO] Running kubeadm join..."
  bash /root/cluster-certs/node-join-cmd.sh

  echo "[INFO] kubeadm join finished"

  touch /var/lib/k8s/step2.done
fi

echo "[INFO] build-k8s.sh finished at $(date)"

