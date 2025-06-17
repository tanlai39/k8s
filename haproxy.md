## HƯỚNG DẪN CÀI HAPROXY

```
root@k8s-haproxy:~# history
    1  ping google.com
    2  cd /etc/netplan/
    3  ls
    4  rm -rf 50*
    5  ls
    6  mv 99-netcfg-vmware.yaml k8s.yaml
    7  ls
    8  vi k8s.yaml
    9  netplan apply
   10  cd
   11  systemctl enable --now systemd-resolved
   12  systemctl restart systemd-resolved
   13  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   14  cat /etc/resolv.conf
   15  apt -y update && apt -y upgrade
   16  ping k8s-master-01
   17  ping k8s-master-02
   18  ping k8s-master-03
   19  ping k8s-node-01
   20  ping k8s-node-02
   21  ping k8s-node-03
   22  ping k8s-tke
   23  ping k8s-tke.tanlv.io.vn
   24  ping tke-k8s.tanlv.io.vn
   25  ping k8s-rancher.tanlv.io.vn
   26  apt install haproxy
   27  vi /etc/haproxy/haproxy.cfg
   28  systemctl restart haproxy
   29  systemctl status haproxy
   30  systemctl enable haproxy
   31  exit
   32  history
root@k8s-haproxy:~#
```

NỘI DUNG FILE haproxy.cfg

```
root@k8s-haproxy:~# cat /etc/haproxy/haproxy.cfg
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http
frontend k8s-frontend
        bind *:6443
        mode tcp
        option tcplog
        default_backend k8s-backend
backend k8s-backend
        mode tcp
        option tcp-check
        balance roundrobin
        default-server inter 3s fall 3 rise 2
        server k8s-master-01 172.17.17.11:6443 check
        server k8s-master-02 172.17.17.12:6443 check
        server k8s-master-03 172.17.17.13:6443 check
root@k8s-haproxy:~#

```

