#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/build-k8s.log
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] build-k8s.sh started at $(date)"

mkdir -p /var/lib/k8s

###############################################################################
# STEP 1 – INSTALL CONTAINERD + K8S
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

  # ---- WAIT KUBELET ----
  echo "[INFO] Waiting for kubelet service..."
  systemctl restart kubelet
  for i in {1..30}; do
    systemctl is-active kubelet >/dev/null 2>&1 && break
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



