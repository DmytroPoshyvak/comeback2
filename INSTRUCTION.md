# Validation Checklist

## Prerequisites

- [ ] Docker installed
- [ ] `kind` installed
- [ ] `kubectl` installed

## 1. Deploy

- [ ] Run the bootstrap script (creates the kind cluster, namespaces, and all resources):

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

## 2. StatefulSet

- [ ] StatefulSet is in the `mysql` namespace and has 3 replicas

```bash
kubectl get statefulset -n mysql
kubectl get pods -n mysql -o wide
```

Expected: `3/3` ready, pods `mysql-0`, `mysql-1`, `mysql-2` are `Running`.

- [ ] Headless Service exists

```bash
kubectl get svc mysql -n mysql
```

Expected: `CLUSTER-IP` is `None`.

- [ ] `volumeClaimTemplates` created PVCs

```bash
kubectl get pvc -n mysql
```

Expected: `claimdata-mysql-0`, `claimdata-mysql-1`, `claimdata-mysql-2` are `Bound`.

- [ ] Sensitive data is read from a Secret

```bash
kubectl get secret secret-mysql -n mysql
kubectl get pod mysql-0 -n mysql -o jsonpath='{.spec.containers[0].env}'
```

Expected: `MYSQL_ROOT_PASSWORD`, `MYSQL_USER`, `MYSQL_PASSWORD` use `secretKeyRef`.

- [ ] `livenessProbe` and `readinessProbe` are configured

```bash
kubectl describe pod mysql-0 -n mysql | grep -E "Liveness|Readiness"
```

- [ ] CPU and memory `requests` and `limits` are set

```bash
kubectl get pod mysql-0 -n mysql -o jsonpath='{.spec.containers[0].resources}'
```

- [ ] `init.sql` is mounted in `/docker-entrypoint-initdb.d` and was executed

```bash
kubectl exec -n mysql mysql-0 -- ls /docker-entrypoint-initdb.d
kubectl exec -n mysql mysql-0 -- mysql -uapp_user -p1234 -e "SHOW TABLES IN todoapp_db;"
```

Expected: `init.sql` is listed, table `counter` exists.

## 3. DNS to `mysql-0`

- [ ] `mysql-0` resolves from the `todoapp` namespace

```bash
kubectl run dns-test --rm -it --restart=Never --image=busybox:1.36 -n todoapp -- \
  nslookup mysql-0.mysql.mysql.svc.cluster.local
```

## 4. Application

- [ ] Deployment is running

```bash
kubectl get pods -n todoapp
kubectl rollout status deployment/todoapp -n todoapp
```

- [ ] DB connection info comes from Secret `secret-db` (`NAME`, `USER`, `PASSWORD`, `HOST`)

```bash
kubectl get secret secret-db -n todoapp
kubectl exec -n todoapp deploy/todoapp -- env | grep -E "^DB_(NAME|USER|HOST)="
```

Expected: `DB_HOST=mysql-0.mysql.mysql.svc.cluster.local`.

- [ ] App connects to the DB without errors

```bash
kubectl logs -n todoapp deploy/todoapp
```

- [ ] Health endpoints respond with HTTP 200

```bash
kubectl port-forward -n todoapp deploy/todoapp 8080:8080
# in another terminal:
curl -i localhost:8080/api/health
curl -i localhost:8080/api/ready
```

## 5. Data persistence

- [ ] Insert a row, delete the pod, check the row is still there

```bash
kubectl exec -n mysql mysql-0 -- mysql -uapp_user -p1234 \
  -e "INSERT INTO todoapp_db.counter (value) VALUES (42);"
kubectl delete pod mysql-0 -n mysql
kubectl wait --for=condition=ready pod/mysql-0 -n mysql --timeout=180s
kubectl exec -n mysql mysql-0 -- mysql -uapp_user -p1234 \
  -e "SELECT * FROM todoapp_db.counter;"
```

## 6. Cleanup

- [ ] Delete the cluster

```bash
kind delete cluster --name todo
```

## Troubleshooting

- Pod not starting: `kubectl describe pod <pod> -n <namespace>`
- MySQL errors: `kubectl logs mysql-0 -n mysql`
- App cannot connect: `kubectl logs -n todoapp deploy/todoapp`
- PVC `Pending`: `kubectl describe pvc <name> -n mysql`

> Note: the 3 MySQL replicas are independent databases (no replication). The app connects only to `mysql-0`.