# DevOps Exercise — Kubernetes Setup with Jenkins, PostgreSQL, Grafana (Traefik Ingress)

This repository contains a complete local Kubernetes-based DevOps stack:

- *Traefik* as Ingress Controller / entry point
- *PostgreSQL* (Helm) with persistent storage + Kubernetes Secrets
- *Jenkins* (Helm) with *JCasC* (Jenkins Configuration as Code) + *Job DSL*
- Jenkins job scheduled *every 5 minutes* that spawns *dynamic Kubernetes agent pods* and inserts the current timestamp into PostgreSQL
- *Prometheus + Grafana* for monitoring
- *Terraform* to provision Grafana datasource + dashboard

> ✅ The goal is a reproducible setup driven by code: YAML/Helm values, Jenkins DSL/JCasC, Terraform, and deployment scripts.

---


## Prerequisites

Install these on your machine:

- Docker Desktop (or Docker Engine)
- kubectl
- Helm
- Minikube
- Terraform
- Git

Verify:

bash
kubectl version --client
helm version
minikube version
terraform -version
git --version


---

## Quick Start (Install / Uninstall)

### Install

bash
./scripts/deploy.sh install


### Uninstall

bash
./scripts/deploy.sh uninstall


> *Windows note*: run deploy.sh using Git Bash or WSL. On Windows, scripts/deploy.ps1 is provided as a helper.

---

## Access (Traefik Ingress)

This setup exposes services via *Traefik*.

### 1) Add hostnames (recommended for local)

Get minikube IP:

bash
minikube ip


Add to your *hosts* file (example IP 192.168.49.2):

- *Windows*: C:\Windows\System32\drivers\etc\hosts
- *macOS/Linux*: /etc/hosts


192.168.49.2 jenkins.local
192.168.49.2 grafana.local
192.168.49.2 traefik.local


### 2) Open in browser

- Jenkins: http://jenkins.local:30080
- Grafana: http://grafana.local:30080
- Traefik Dashboard: http://traefik.local:30080

> Ports are NodePorts mapped by Traefik service:
> - web: *30080*
> - websecure: *30443*

---

## Credentials

### Jenkins
- Username: admin
- Password: admin123!

### Grafana
- Username: admin
- Password: admin123!

### PostgreSQL
- DB: devopsdb
- User: devopsuser
- Password is stored in the Kubernetes secret postgres-secret.

---

## Key Implementation Details

### PostgreSQL Secrets (Important)

To avoid installation issues across environments, the PostgreSQL secret includes *both* keys:

- postgres-password (admin/postgres user)
- password (application user: devopsuser)

Files:
- k8s/postgres-secret-devops.yaml
- k8s/postgres-secret-jenkins.yaml

> Why two secrets? Kubernetes secrets are *namespaced*. Jenkins agents run in the jenkins namespace, so the same secret name exists in both namespaces.

### PostgreSQL Helm values

k8s/postgres-values.yaml uses existingSecret: postgres-secret and explicitly maps secret keys:

- adminPasswordKey: postgres-password
- userPasswordKey: password

### Jenkins JCasC + Job DSL

k8s/jenkins-values.yaml contains JCasC configuration:

- Security realm + admin user
- Kubernetes cloud configuration
- Job DSL that creates the pipeline job insert-time-into-postgres

*Important fix: the pipeline injects DB password from secret key *password** (not postgres-password) because the DB user is devopsuser.

### Traefik Ingress Class

k8s/traefik-values.yaml enables Traefik IngressClass and sets it as default:

- ingressClass.enabled: true
- ingressClass.isDefaultClass: true
- name: traefik

Ingress manifests use:

yaml
spec:
  ingressClassName: traefik


This ensures Traefik reliably picks up ingresses in different environments.

---

## Validation / Proof Commands

### Cluster health

bash
kubectl get nodes
kubectl get pods -A


### Traefik

bash
kubectl get pods -n devops
kubectl get svc -n devops traefik
kubectl get ingressclass
kubectl get ingress -A
kubectl logs -n devops deploy/traefik --tail=120


### PostgreSQL

Verify table exists:

bash
kubectl run psql-client -n devops --rm -it --image=postgres:16-alpine -- sh
export PGPASSWORD="SuperStrongPass123!"
psql -h postgres-postgresql.devops.svc.cluster.local -U devopsuser -d devopsdb -c "\\dt"


Verify inserts:

bash
psql -h postgres-postgresql.devops.svc.cluster.local -U devopsuser -d devopsdb -c "select * from time_logs order by id desc limit 5;"


### Jenkins job

- In Jenkins UI, run *insert-time-into-postgres*
- Watch for dynamic agent pods:

bash
kubectl get pods -n jenkins


---

## Monitoring (Grafana + Terraform)

### Grafana install
Grafana is installed via Helm values in k8s/grafana-values.yaml.

### Terraform apply

bash
cd terraform
terraform init
terraform apply


This provisions:
- Grafana datasource (Prometheus)
- Dashboard for key PostgreSQL / cluster metrics

---

## Troubleshooting

### 1) PostgreSQL install fails due to secret key
Symptom: chart expects password key.

✅ Fix: ensure the secret includes *both* password and postgres-password keys (see k8s/postgres-secret-*.yaml).

### 2) Traefik installed but does not route ingresses
Symptom: services not reachable via hostnames.

✅ Fix:
- Ensure Traefik IngressClass enabled in k8s/traefik-values.yaml
- Ensure ingress manifests set spec.ingressClassName: traefik

### 3) Jenkins shows restarts on low-resource local clusters
Jenkins is JVM-based and may restart on low memory.

✅ Fix:
- Adjust controller.resources in k8s/jenkins-values.yaml
- Run on a machine with more RAM/CPU for best stability

---

## Notes for Reviewers

To redeploy cleanly:

bash
./scripts/deploy.sh uninstall
./scripts/deploy.sh install


If you need a quick health snapshot:

bash
kubectl get pods -A
kubectl get ingressclass
kubectl get ingress -A


---

## License
Internal assignment repository.