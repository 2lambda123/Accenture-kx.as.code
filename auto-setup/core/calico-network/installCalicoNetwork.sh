#!/bin/bash -x
set -euo pipefail

# Ensure Kubernetes is available before proceeding to the next step
timeout -s TERM 6000 bash -c \
    'while [[ "$(curl -s -k https://localhost:6443/livez)" != "ok" ]];\
do sleep 5;\
done'

# Install Calico Network
curl https://docs.projectcalico.org/v3.17/manifests/calico.yaml --output ${installationWorkspace}/calico.yaml
sed -i -e '/^            - name: FELIX_HEALTHENABLED/{:a; N; /\n              value: "true"/!ba; a\            - name: IP_AUTODETECTION_METHOD\n              value: "interface='${netDevice}'"' -e '}' ${installationWorkspace}/calico.yaml
kubectl apply -f ${installationWorkspace}/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
