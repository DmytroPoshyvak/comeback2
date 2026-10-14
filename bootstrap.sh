#!/bin/bash
set -e

K8S_DIR="k8s"   # <-- заміни на назву папки, де лежать namespace.yml, pvc.yml, secret.yml тощо
CLUSTER_NAME="todo"

# 1. Кластер з твого cluster.yml
if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME already exists, skipping"
else
  kind create cluster --name "$CLUSTER_NAME" --config cluster.yml
fi

# 2. Namespaces
kubectl apply -f "$K8S_DIR/namespace.yml"
kubectl create namespace mysql --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -

# 3. MySQL: secret і configmap перед statefulset
kubectl apply -f st-sercret.yml
kubectl apply -f st-configMap.yml
kubectl apply -f service.yml
kubectl apply -f statefulSet.yml
kubectl rollout status statefulset/mysql -n mysql --timeout=300s

# 4. Application: усе з папки (secret, configmap, pv, pvc, deployment, nodeport, hpa)
kubectl apply -f "$K8S_DIR/"
kubectl rollout status deployment/todoapp -n todoapp --timeout=180s

echo "Done"
kubectl get pods -A