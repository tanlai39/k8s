#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/build-dns.log
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] build-dns.sh started at $(date)"
mkdir -p /var/lib/dns
rm -rf /etc/netplan/*

cat > /etc/netplan/tanlv.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      dhcp6: false
      addresses:
        - 10.0.0.250/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        search:
          - tanlv.local
        addresses:
          - 8.8.8.8
EOF

systemctl enable --now systemd-resolved
ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf

hostnamectl set-hostname dns.tanlv.local
echo "127.0.1.1 dns.tanlv.local" >> /etc/hosts
timedatectl set-timezone Asia/Ho_Chi_Minh

echo "[INFO] Waiting for network..."
for i in {1..30}; do
  ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && break
  sleep 2
done

# ---------------- TIME ----------------
echo "[INFO] network OK, Waitting 2 phut lam tiep"
sleep 60
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
echo "[INFO] STEP 1 install bind9 running..."

apt -y install bind9 bind9utils
cat > /etc/bind/named.conf <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
include "/etc/bind/named.conf.internal-zones";
EOF

cat > /etc/bind/named.conf.options <<'EOF'
acl internal-network {
        10.0.0.0/24;
};
options {
        directory "/var/cache/bind";

        // If there is a firewall between you and nameservers you want
        // to talk to, you may need to fix the firewall to allow multiple
        // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

        // If your ISP provided one or more IP addresses for stable
        // nameservers, you probably want to use them as forwarders.
        // Uncomment the following block, and insert the addresses replacing
        // the all-0's placeholder.

        // forwarders {
        //      0.0.0.0;
        // };

        //========================================================================
        // If BIND logs error messages about the root key being expired,
        // you will need to update your keys.  See https://www.isc.org/bind-keys
        //========================================================================
        dnssec-validation auto;

        listen-on-v6 { none; };
};
EOF

cat > /etc/bind/named.conf.internal-zones <<'EOF'
zone "tanlv.local" IN {
        type primary;
        file "/etc/bind/tanlv.local";
        allow-update { none; };
};
zone "0.0.10.in-addr.arpa" IN {
        type primary;
        file "/etc/bind/0.0.10.db";
        allow-update { none; };
};
zone "tanlv.io.vn" IN {
        type primary;
        file "/etc/bind/tanlv.io.vn";
        allow-update { none; };
};
EOF

cat > /etc/default/named <<'EOF'
# run resolvconf?
#RESOLVCONF=no

# startup options for the server
#OPTIONS="-u bind"
OPTIONS="-u bind -4"
EOF

cat > /etc/bind/tanlv.local <<'EOF'
$TTL 86400
@   IN  SOA     dns.tanlv.local. root.tanlv.local. (
        ;; any numerical values are OK for serial number
        ;; recommended : [YYYYMMDDnn] (update date + number)
        2024042901  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        IN  NS      dns.tanlv.local.
        IN  A       10.0.0.250

dns                      IN  A       10.0.0.250
control-plane-01         IN  A       10.0.0.11
control-plane-02         IN  A       10.0.0.12
control-plane-03         IN  A       10.0.0.13
node-01                  IN  A       10.0.0.21
node-02                  IN  A       10.0.0.22
node-03                  IN  A       10.0.0.23
tanlv-tke                IN  A       10.0.0.11
EOF

cat > /etc/bind/tanlv.io.vn <<'EOF'
$TTL 86400
@   IN  SOA     dns.tanlv.io.vn. root.tanlv.io.vn. (
        ;; any numerical values are OK for serial number
        ;; recommended : [YYYYMMDDnn] (update date + number)
        2024042901  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        IN  NS      dns.tanlv.io.vn.
        IN  A       10.0.0.250

tanlv-tke                 IN  A       10.0.0.11
dns                       IN  A       10.0.0.250
EOF

cat > /etc/bind/0.0.10.db <<'EOF'
$TTL 86400
@   IN  SOA     dns.tanlv.local. root.tanlv.local. (
        2024042901  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        ;; define Name Server
        IN  NS      dns.tanlv.local.

250      IN  PTR     dns.tanlv.local.
11       IN  PTR     control-plane-01.tanlv.local.
12       IN  PTR     control-plane-02.tanlv.local.
13       IN  PTR     control-plane-03.tanlv.local.
21       IN  PTR     node-01.tanlv.local.
22       IN  PTR     node-02.tanlv.local.
23       IN  PTR     node-03.tanlv.local.
EOF


named-checkconf
named-checkzone 0.0.10.in-addr.arpa /etc/bind/0.0.10.db
named-checkzone tanlv.local /etc/bind/tanlv.local
named-checkzone tanlv.io.vn /etc/bind/tanlv.io.vn
systemctl restart named
systemctl status named

echo "[INFO] đổi lại DNS"
cat > /etc/netplan/tanlv.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      dhcp6: false
      addresses:
        - 10.0.0.250/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        search:
          - tanlv.local
        addresses:
          - 10.0.0.250
EOF
touch /var/lib/k8s/build-dns.done
echo "[INFO] build-dns.sh finished at $(date)"
