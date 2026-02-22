Param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('install','uninstall')]
  [string]$Action
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }

function Ensure-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing command: $name. Please install it first."
  }
}

Ensure-Command minikube
Ensure-Command kubectl
Ensure-Command helm
Ensure-Command docker

$RepoRoot = (Resolve-Path "..").Path
Set-Location $RepoRoot

if ($Action -eq 'install') {
  Write-Info "Starting Minikube (docker driver)..."
  minikube start --driver=docker --cpus=4 --memory=8192

  $MINIKUBE_IP = (minikube ip).Trim()
  $DOMAIN = "$MINIKUBE_IP.nip.io"
  Write-Info "Minikube IP: $MINIKUBE_IP"

  kubectl apply -f k8s/namespaces.yaml

  Write-Info "Installing Traefik..."
  helm repo add traefik https://traefik.github.io/charts | Out-Null
  helm repo update | Out-Null
  helm upgrade --install traefik traefik/traefik -n devops -f k8s/traefik-values.yaml

  Write-Info "Installing Prometheus stack (Grafana disabled)..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts | Out-Null
  helm repo update | Out-Null
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring -f k8s/kube-prometheus-stack-values.yaml

  kubectl apply -f k8s/postgres-secret-devops.yaml
  kubectl apply -f k8s/postgres-secret-jenkins.yaml

  Write-Info "Installing PostgreSQL..."
  helm repo add bitnami https://charts.bitnami.com/bitnami | Out-Null
  helm repo update | Out-Null
  helm upgrade --install postgres bitnami/postgresql -n devops -f k8s/postgres-values.yaml
  kubectl -n devops rollout status statefulset/postgres-postgresql --timeout=300s

  Write-Info "Init DB table..."
  kubectl apply -f k8s/postgres-init-job.yaml
  kubectl -n devops wait --for=condition=complete job/postgres-init --timeout=300s

  Write-Info "Build worker image in Minikube docker..."
  & minikube -p minikube docker-env --shell powershell | Invoke-Expression
  docker build -t time-writer:1.0 .\jenkins\worker

  Write-Info "Installing Grafana..."
  helm repo add grafana https://grafana.github.io/helm-charts | Out-Null
  helm repo update | Out-Null
  helm upgrade --install grafana grafana/grafana -n devops -f k8s/grafana-values.yaml

  Write-Info "Installing Jenkins (JCasC + scheduled job)..."
  helm repo add jenkins https://charts.jenkins.io | Out-Null
  helm repo update | Out-Null
  helm upgrade --install jenkins jenkins/jenkins -n jenkins -f k8s/jenkins-values.yaml

  Write-Info "Render + apply ingresses..."
  $ingDir = Join-Path $RepoRoot "k8s\ingresses"
  $outDir = Join-Path $RepoRoot "k8s\rendered"
  New-Item -Force -ItemType Directory $outDir | Out-Null

  Get-ChildItem "$ingDir\*.tpl" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content.Replace('__DOMAIN__', $DOMAIN)
    $outFile = Join-Path $outDir ($_.BaseName)
    Set-Content -Path $outFile -Value $content -Encoding UTF8
  }
  kubectl apply -f $outDir

  Write-Host "" 
  Write-Host "Access:" -ForegroundColor Green
  Write-Host "  Jenkins : http://jenkins.$DOMAIN:30080" -ForegroundColor Green
  Write-Host "  Grafana : http://grafana.$DOMAIN:30080" -ForegroundColor Green
  Write-Host "  Traefik : http://traefik.$DOMAIN:30080" -ForegroundColor Green
  Write-Host "" 
  Write-Host "Credentials:" -ForegroundColor Green
  Write-Host "  Jenkins : admin / admin123!" -ForegroundColor Green
  Write-Host "  Grafana : admin / admin123!" -ForegroundColor Green
  Write-Host "" 
  Write-Info "Next: run Terraform from .\terraform (README)"

} else {
  helm uninstall jenkins -n jenkins 2>$null
  helm uninstall grafana -n devops 2>$null
  helm uninstall postgres -n devops 2>$null
  helm uninstall traefik -n devops 2>$null
  helm uninstall monitoring -n monitoring 2>$null

  kubectl delete namespace jenkins --ignore-not-found
  kubectl delete namespace devops --ignore-not-found
  kubectl delete namespace monitoring --ignore-not-found

  minikube stop
  Write-Info "Removed ✅"
}
