#!/bin/bash -x
set -euo pipefail

# Install LetsEncrypt SSL issuer
if [[ -n "${sslDomainAdminEmail}" ]]; then
echo '''
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
 name: letsencrypt-staging
spec:
 acme:
   # The ACME server URL
   server: https://acme-staging-v02.api.letsencrypt.org/directory
   # Email address used for ACME registration
   email: '${sslDomainAdminEmail}'
   # Name of a secret used to store the ACME account private key
   privateKeySecretRef:
     name: letsencrypt-staging
   # Enable the HTTP-01 challenge provider
   solvers:
   - http01:
       ingress:
         class:  nginx
''' | sudo tee ${installationWorkspace}/letsencrypt-issuer.yaml
kubectl apply -f ${installationWorkspace}/letsencrypt-issuer.yaml
else
  log_warn "sslDomainAdminEmail property not set in profile-config.json. Skipping setting up LetsEncrypt issuer for Cert-Manager"
fi