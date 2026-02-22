apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-dashboard
  namespace: devops
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: traefik.__DOMAIN__
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: traefik
                port:
                  number: 9000
