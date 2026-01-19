https://viblo.asia/p/k8s-phan-8-monitoring-tren-kubernetes-cluster-dung-prometheus-va-grafana-Qbq5QRkEKD8
```
  149  rm -rf prometheus/
  150  cd /home/sysadmin/kubernetes_installation/
  151  mkdir prometheus
  152  cd
  153  cd /home/sysadmin/kubernetes_installation/prometheus/
  154  cd
  155  cd /home/sysadmin/kubernetes_installation/
  156  cd prometheus/
  157  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  158  helm repo add stable https://charts.helm.sh/stable
  159  helm repo update
  160  helm search repo prometheus |egrep "stack|CHART"
  161  ls
  162  helm pull prometheus-community/kube-prometheus-stack --version 81.0.0
  163  ls
  164  tar -xzf kube-prometheus-stack-81.0.0.tgz
  165  ls
  166  cd kube-prometheus-stack
  167  ls
  168  cp values.yaml values-prometheus.yaml
  169  cat values-prometheus.yaml
  170  vi values-prometheus.yaml
  171  ls
  172  kubectl create ns monitoring
  173  helm -n monitoring install prometheus-grafana-stack -f values-prometheus-clusterIP.yaml kube-prometheus-stack
  174  helm install prometheus-grafana-stack   prometheus-community/kube-prometheus-stack   -n monitoring   -f values-prometheus-clusterIP.yaml
  175  ls
  176  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  177  vi values-prometheus.yaml
  178  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  179  vi values-prometheus.yaml
  180  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  181  vi values-prometheus.yaml
  182  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  183  vi values-prometheus.yaml
  184  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  185  vi values-prometheus.yaml
  186  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  187  vi values-prometheus.yaml
  188  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  189  vi values-prometheus.yaml
  190  helm install prometheus-grafana-stack ./ -n monitoring -f values-prometheus.yaml
  191  kubectl get pods -n monitoring
  192  kubectl get svc -n monitoring
  193  kubectl get ingress -n monitoring
  194  kubectl describe ingress prometheus-grafana-stack-k-prometheus -n monitoring
  195  vi values-prometheus.yaml
  196  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  197  kubectl get ingress -n monitoring
  198  vi values-prometheus.yaml
  199  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  200  kubectl get ingress -n monitoring
  201  vi values-prometheus.yaml
  202  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  203  kubectl get ingress -n monitoring
  204  kubectl -n monitoring port-forward svc/prometheus-grafana-stack 3000:80
  205  kubectl get deployment
  206  kubectl get deployment --all-namespaces
  207  vi values-prometheus.yaml
  208  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  209  vi values-prometheus.yaml
  210  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  211  kubectl get ingress -n monitoring
  212  vi values-prometheus.yaml
  213  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  214  vi values-prometheus.yaml
  215  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  216  kubectl get secret
  217  cd
  218  cd ~/k8s
  219  tree ~/k8s
  220  cd
  221  cd /root/k8s/apps/tanlv/
  222  git add .
  223  git commit -m "fix tls secret type to kubernetes.io/tls"
  224  cd
  225  cd ~/k8s
  226  git pull
  227  cd
  228  cd /root/k8s/apps/tanlv/
  229  cat secret-tls.yaml
  230  kubectl apply -f secret-tls.yaml
  231  kubectl get ingress tls-tpcoms-ingress -o yaml | grep secretName
  232  kubectl get ingress --all-namespaces
  233  kubectl get ingress tanlv-web-ingress -n default -o yaml | grep secretName
  234  ls
  235  kubectl delete -f secret-tls.yaml
  236  kubectl apply -f secret-tls.yaml
  237  kubectl get secret
  238  cd
  239  tree ~/k8s
  240  cp /root/k8s/apps/tanlv/secret-tls.yaml /root/k8s/monitoring/grafana/
  241  cd /root/k8s/monitoring/grafana/
  242  ls
  243  git add .
  244  git status
  245  git push
  246  cd /k8s/
  247  cd /root/k8s/
  248  ls
  249  git add .
  250  git status
  251  git push
  252  tree ~/k8s
  253  git add monitoring
  254  git status
  255  git git push
  256  git  push
  257  git add monitoring
  258  git commit -m "add grafana tls secret"
  259  git push origin main
  260  cd
  261  cd /root/k8s/monitoring/grafana/
  262  ls
  263  git pull
  264  cat secret-tls.yaml
  265  kubectl apply -f .
  266  kubectl get secret
  267  kubectl delete -f secret-tls.yaml
  268  kubectl get secret
  269  kubectl apply -f secret-tls.yaml -n monitoring
  270  kubectl get secret
  271  kubectl get secret --all-namespaces
  272  cd
  273  cd /home/sysadmin/kubernetes_installation/
  274  ls
  275  cd prometheus/
  276  ls
  277  cd kube-prometheus-stack/
  278  ls
  279  vi values-prometheus.yaml
  280  cd
  281  tree ~/k8s
  282  cd /root/k8s/monitoring/
  283  cp grafana//secret-tls.yaml prometheus/
  284  cd prometheus/
  285  ls
  286  git add .
  287  git status
  288  git commit -m "add tls prometheus"
  289  git push origin main
  290  git pull
  291  ls
  292  vi secret-tls.yaml
  293  kubectl apply -f secret-tls.yaml
  294  cd
  295  kubectl get secret -n monitoring
  296  kubectl get secret
  297  cd ~/k8s/monitoring/prometheus/
  298  ls
  299  kubectl delete -f secret-tls.yaml
  300  kubectl apply -f secret-tls.yaml -n monitoring
  301  kubectl get secret
  302  kubectl get secret -n monitoring
  303  cd
  304  cd /home/sysadmin/kubernetes_installation/prometheus/
  305  ls
  306  cd kube-prometheus-stack/
  307  ls
  308  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  309  vi values-prometheus.yaml
  310  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  311  kube get secret -n monitoring
  312  kubectl get secret -n monitoring
  313  vi values-prometheus.yaml
  314  cd
  315  cd /root/k8s/monitoring/
  316  ls
  317  mkdir alertmanager
  318  ls
  319  cp grafana/secret-tls.yaml alertmanager/
  320  cd alertmanager/
  321  ls
  322  git add .
  323  git status
  324  git commit -m "add tls alertmanager"
  325  git push origin main
  326  git pull
  327  vi secret-tls.yaml
  328  kubectl apply -f secret-tls.yaml  -n monitoring
  329  kubectl get secret -n monitoring
  330  cd
  331  cd /home/sysadmin/kubernetes_installation/prometheus/kube-prometheus-stack/
  332  ls
  333  helm upgrade prometheus-grafana-stack ./   -n monitoring   -f values-prometheus.yaml
  334  history
root@cicd:~#
```

```
vi values-prometheus.yaml
```

```
grafana:
  enabled: true
  grafana.ini:
    server:
      domain: grafana.tanlv.io.vn
      root_url: http://grafana.tanlv.io.vn/
      serve_from_sub_path: false
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.tanlv.io.vn
    path: /
    tls:
      - hosts:
          - grafana.tanlv.io.vn
        secretName: tls-grafana.tanlv-io-vn
prometheus:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - prometheus.tanlv.io.vn
    paths:
      - /
    tls:
      - hosts:
          - prometheus.tanlv.io.vn
        secretName: tls-prometheus.tanlv-io-vn
  prometheusSpec:
    externalUrl: http://prometheus.tanlv.io.vn
    routePrefix: /
alertmanager:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - alertmanager.tanlv.io.vn
    paths:
      - /
    tls:
      - hosts:
          - alertmanager.tanlv.io.vn
        secretName: tls-alertmanager.tanlv-io-vn
  alertmanagerSpec:
    externalUrl: https://alertmanager.tanlv.io.vn
    routePrefix: /
```
