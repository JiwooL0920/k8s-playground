
```
kind create cluster --name redis-sentinel
helm repo add bitnami
helm pull bitnami/redis --untar

# change values.yaml
sentinel.enabled: true

helm install redis-sentinel . -f values.yaml



```