#!/bin/bash -x
set -euo pipefail

# Create postgresql password or use existing if it already exists
postgresqlPasswordExists=$(kubectl get secret --namespace artifactory artifactory-oss-postgresql -o json | jq -r '.data."postgresql-password"')
if [[ -n ${postgresqlPasswordExists}   ]]; then
    export postgresqlPassword=$(echo ${postgresqlPasswordExists} | base64 --decode)
    log_info "Jfrog Artifactory postgresql password already exists. Using that one"
else
    export postgresqlPassword=$(pwgen -1s 32)
    log_info "Jfrog Artifactory postgresql password does not exist. Creating a new one"
fi
