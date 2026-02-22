terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.13"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = "${var.grafana_user}:${var.grafana_password}"
}

resource "grafana_data_source" "prometheus" {
  type        = "prometheus"
  name        = "Prometheus"
  url         = var.prometheus_url
  access_mode = "proxy"
  is_default  = true
}

resource "grafana_dashboard" "postgres_dashboard" {
  config_json = file("${path.module}/dashboard.json")
  depends_on  = [grafana_data_source.prometheus]
}
