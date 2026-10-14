#!/bin/bash
set -e

kind create cluster --name todo --config cluster.yml

kubectl create namespace mysql
kubectl create namespace todoapp

# MySQL: спершу secret і configmap, потім service і statefulset
kubectl apply -f secret-mysql.yml
kubectl apply -f configmap-mysql.yml
kubectl apply -f service.yml
kubectl apply -f statefulSet.yml
kubectl rollout status statefulset/mysql -n mysql --timeout=300s

# App
kubectl apply -f secret-db.yml
kubectl apply -f app-secret.yml
kubectl apply -f app-config.yml
kubectl apply -f pvc.yml
kubectl apply -f deployment.yml
kubectl rollout status deployment/todoapp -n todoapp --timeout=180s