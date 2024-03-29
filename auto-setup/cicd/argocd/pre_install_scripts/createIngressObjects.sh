#!/bin/bash

# The annotation for HTTP Version 1.0 below is a workaround for an issue described here: https://github.com/argoproj/argo-cd/issues/3896
echo '''
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-http-ingress
  namespace: '${namespace}'
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.0"
spec:
  rules:
  - http:
      paths:
      - backend:
          service:
            name: argocd-server
            port:
              number: 80
        path: /
        pathType: Prefix
    host: '${componentName}'.'${baseDomain}'
  tls:
  - hosts:
    - '${componentName}'.'${baseDomain}'
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-grpc-ingress
  namespace: '${namespace}'
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - http:
      paths:
      - backend:
          service:
            name: argocd-server
            port:
              number: 80
        path: /
        pathType: Prefix
    host: grpc.'${componentName}'.'${baseDomain}'
  tls:
  - hosts:
    - grpc.'${componentName}'.'${baseDomain}'
---
''' | kubectl apply -n ${namespace} -f -
