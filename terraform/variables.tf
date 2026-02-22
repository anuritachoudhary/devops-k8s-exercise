variable "grafana_url" {
  type        = string
  description = "Grafana base URL (Ingress), e.g. http://grafana.<MINIKUBE_IP>.nip.io"
}

variable "grafana_user" {
  type        = string
  description = "Grafana admin user"
  default     = "admin"
}

variable "grafana_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
}

variable "prometheus_url" {
  type        = string
  description = "Prometheus URL reachable from Grafana (cluster DNS)"
  default     = "http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
}
