#!/bin/bash

echo """
provider: AWS
region: eu-central-1
aws_access_key_id: ${minioAccessKey}
aws_secret_access_key: ${minioSecretKey}
aws_signature_version: 4
host: ${s3ObjectStoreDomain}
endpoint: \"http://minio-service:9000\"
path_style: true
""" | tee ${installationWorkspace}/rails.minio.yaml

# Install S3 Secrets
kubectl get secret object-storage -n ${namespace} ||
    kubectl create secret generic object-storage --dry-run=client -o yaml \
        --from-file=connection=${installationWorkspace}/rails.minio.yaml \
        -n ${namespace} | kubectl apply -f -

kubectl get secret generic s3cmd-config -n ${namespace} ||
    kubectl create secret generic s3cmd-config --dry-run=client -o yaml \
        --from-file=config=${installationWorkspace}/rails.minio.yaml \
        -n ${namespace} | kubectl apply -f -

# Generate initial root password
export gitlabRootPassword=$(managedPassword "gitlab-root-password" "gitlab")

# Set initial root password
kubectl get secret ${componentName}-gitlab-initial-root-password -n ${namespace} ||
    kubectl create secret generic ${componentName}-gitlab-initial-root-password \
        --from-literal=password=${gitlabRootPassword} \
        -n ${namespace}

# Add KX.AS.CODE CA cert to Gitlab namespace (important for Gitlab to act as OIDC provider - including global.hosts.https=true + gitlab.webservice.ingress.tls.secretName parameters)
kubectl get secret kx.as.code-wildcard-cert --namespace=${namespace} ||
    kubectl create secret generic kx.as.code-wildcard-cert \
        --from-file=${installationWorkspace}/kx-certs \
        --namespace=${namespace}

# Create intermediate certificate secret for gitlab sso
kubectl get secret intermediate-ca --namespace=${namespace} || \
    kubectl create secret generic intermediate-ca --from-file=intermediate.pem=${certificatesWorkspace}/kx_intermediate_ca.pem -n ${namespace}

# Create root certificate secret for gitlab sso
kubectl get secret root-ca --namespace=${namespace} || \
    kubectl create secret generic root-ca --from-file=root.pem=${certificatesWorkspace}/kx_root_ca.pem -n ${namespace}

# Create server certificate secret for gitlab sso
kubectl get secret server-crt --namespace=${namespace} || \
    kubectl create secret generic server-crt --from-file=server.pem=${certificatesWorkspace}/kx_server.pem -n ${namespace}

# Create docker pull secret for private registry
log_info "Adding user gitlab user to docker-registry htpasswd file"
dockerRegistryAddUser "gitlab"
passwordForAddedUser=$(managedApiKey "docker-registry-gitlab-password" "docker-registry")
kubectl get secret gitlab-image-pull-secret --namespace=${namespace} || \
    kubectl create secret docker-registry gitlab-image-pull-secret \
    --namespace ${namespace} \
    --docker-server="https://docker-registry.${baseDomain}" \
    --docker-username="gitlab" \
    --docker-password="${passwordForAddedUser}"
