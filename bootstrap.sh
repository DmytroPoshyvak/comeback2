#!/bin/bash
set -e

K8S_DIR=".infrastructure"
CLUSTER_NAME="todo"

# 1. Cluster
if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME already exists, skipping"
else
  kind create cluster --name "$CLUSTER_NAME" --config cluster.yml
fi

# 2. Namespaces
kubectl create namespace mysql --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$K8S_DIR/namespace.yml"

# 3. MySQL (secret and configmap before statefulset)
kubectl apply -f st-sercret.yml
kubectl apply -f st-configMap.yml
kubectl apply -f service.yml
kubectl apply -f statefulSet.yml
kubectl rollout status statefulset/mysql -n mysql --timeout=600s

# 4. Application
kubectl apply -f "$K8S_DIR/secret.yml"
kubectl apply -f "$K8S_DIR/pv.yml"
kubectl apply -f "$K8S_DIR/pvc.yml"
kubectl apply -f "$K8S_DIR/"
kubectl rollout status deployment/todoapp -n todoapp --timeout=180s

echo "Done"
kubectl get pods -A