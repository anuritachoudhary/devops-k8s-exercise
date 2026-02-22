apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: devops
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: grafana.__DOMAIN__
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
