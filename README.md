# CXDO DevOps Exercise (Local) — Minikube + Traefik + Jenkins + PostgreSQL + Grafana + Prometheus

This repo sets up a complete local Kubernetes solution:

- **Traefik** as Ingress Controller (NodePort on Minikube)
- **PostgreSQL** (persistent) + exporter metrics
- **Jenkins** controller + **dynamic Kubernetes worker pods** (scheduled every 5 minutes)
- **Prometheus Operator stack** (Prometheus only; Grafana installed separately)
- **Grafana** exposed via Traefik
- **Terraform** to configure Grafana datasource + dashboard (PostgreSQL CPU/Mem/Throughput)

✅ **No port-forwarding**. All services are reached through **Traefik Ingress**.

---

## Prerequisites (Windows)
Install: Docker Desktop, Minikube, kubectl, Helm, Terraform, Git.

Verify:
```powershell
minikube version
kubectl version --client
helm version
terraform -version
git --version
```

---

## Install
Run:
```powershell
cd .\scripts
.\deploy.ps1 install
```

The script prints URLs using your Minikube IP + **nip.io** (no hosts file edit needed).

---

## Access URLs
- Jenkins  : `http://jenkins.<MINIKUBE_IP>.nip.io:30080`
- Grafana  : `http://grafana.<MINIKUBE_IP>.nip.io:30080`
- Traefik  : `http://traefik.<MINIKUBE_IP>.nip.io:30080`

Credentials:
- Jenkins: `admin / admin123!`
- Grafana: `admin / admin123!`

---

## Terraform (Grafana dashboard)
After install:
```powershell
cd .	erraform
terraform init
terraform apply -auto-approve `
  -var "grafana_url=http://grafana.<MINIKUBE_IP>.nip.io:30080" `
  -var "grafana_user=admin" `
  -var "grafana_password=admin123!"
```

---

## Verify DB inserts
Jenkins job: **insert-time-into-postgres** (runs every 5 mins)

Check table:
```powershell
kubectl -n devops run psql-client --rm -it --image=bitnami/postgresql:16 -- bash
```
Inside:
```bash
export PGPASSWORD="SuperStrongPass123!"
psql -h postgres-postgresql.devops.svc.cluster.local -U devopsuser -d devopsdb   -c "SELECT * FROM time_logs ORDER BY id DESC LIMIT 10;"
```

---

## Uninstall
```powershell
cd .\scripts
.\deploy.ps1 uninstall
```

---

## Notes
- True Jenkins HA needs RWX storage; local Minikube typically provides RWO.
- Traefik is exposed via NodePort 30080/30443; Ingress routes handle Jenkins/Grafana.
