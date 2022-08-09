kubernetesHealthCheck() {

    # Ensure Kubernetes is available before proceeding to the next step
    timeout -s TERM 6000 bash -c \
        'while [[ "$(kubectl get --raw=\"/readyz\"" != "ok" ]];\
    do sleep 5;\
    done'

}