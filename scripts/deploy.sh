#!/usr/bin/env bash
set -euo pipefail
ACTION="${1:-}"
if [[ "$ACTION" != "install" && "$ACTION" != "uninstall" ]]; then
  echo "Usage: $0 install|uninstall"; exit 1
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ "$ACTION" == "install" ]]; then
  minikube start --driver=docker --cpus=4 --memory=8192
  MINIKUBE_IP="$(minikube ip)"; DOMAIN="$MINIKUBE_IP.nip.io"
  kubectl apply -f k8s/namespaces.yaml
  helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install traefik traefik/traefik -n devops -f k8s/traefik-values.yaml
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring -f k8s/kube-prometheus-stack-values.yaml
  kubectl apply -f k8s/postgres-secret-devops.yaml
  kubectl apply -f k8s/postgres-secret-jenkins.yaml
  helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install postgres bitnami/postgresql -n devops -f k8s/postgres-values.yaml
  kubectl -n devops rollout status statefulset/postgres-postgresql --timeout=300s
  kubectl apply -f k8s/postgres-init-job.yaml
  kubectl -n devops wait --for=condition=complete job/postgres-init --timeout=300s
  eval "$(minikube docker-env)"; docker build -t time-writer:1.0 ./jenkins/worker
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install grafana grafana/grafana -n devops -f k8s/grafana-values.yaml
  helm repo add jenkins https://charts.jenkins.io >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install jenkins jenkins/jenkins -n jenkins -f k8s/jenkins-values.yaml
  mkdir -p k8s/rendered
  for f in k8s/ingresses/*.tpl; do out="k8s/rendered/$(basename "${f%.tpl}")"; sed "s/__DOMAIN__/${DOMAIN}/g" "$f" > "$out"; done
  kubectl apply -f k8s/rendered
  echo "Jenkins: http://jenkins.$DOMAIN:30080"; echo "Grafana: http://grafana.$DOMAIN:30080"; echo "Traefik: http://traefik.$DOMAIN:30080"
else
  helm uninstall jenkins -n jenkins >/dev/null 2>&1 || true
  helm uninstall grafana -n devops >/dev/null 2>&1 || true
  helm uninstall postgres -n devops >/dev/null 2>&1 || true
  helm uninstall traefik -n devops >/dev/null 2>&1 || true
  helm uninstall monitoring -n monitoring >/dev/null 2>&1 || true
  kubectl delete namespace jenkins --ignore-not-found
  kubectl delete namespace devops --ignore-not-found
  kubectl delete namespace monitoring --ignore-not-found
  minikube stop
fi
