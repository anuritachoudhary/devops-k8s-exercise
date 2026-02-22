output "datasource_name" {
  value = grafana_data_source.prometheus.name
}

output "dashboard_uid" {
  value = jsondecode(grafana_dashboard.postgres_dashboard.config_json).uid
}
