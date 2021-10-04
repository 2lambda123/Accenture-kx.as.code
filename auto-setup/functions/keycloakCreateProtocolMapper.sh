createKeycloakProtocolMapper () {

    # Source Keycloak Environment
    sourceKeyCloakEnvironment

    # Call function to login to Keycloak
    keycloakLogin

    protocolMapper=$(kubectl -n ${kcNamespace} exec ${kcPod} --container ${kcContainer} -- \
        ${kcAdmCli} get clients/${1}/protocol-mappers/models \
        --realm ${kcRealm})

    if [[ -z ${protocolMapper} ]]; then
        # Create client scope protocol mapper
        kubectl -n ${kcNamespace} exec ${kcPod} --container ${kcContainer} -- \
            ${kcAdmCli} create clients/${1}/protocol-mappers/models \
                --realm ${kcRealm} \
                -s "name=groups" \
                -s "protocol=openid-connect" \
                -s "protocolMapper=oidc-group-membership-mapper" \
                -s 'config."claim.name"=groups' \
                -s 'config."access.token.claim"=true' \
                -s 'config."userinfo.token.claim"=true' \
                -s 'config."id.token.claim"=true' \
                -s 'config."full.path"=true' \
                -s 'config."jsonType.label"=String'
    else
        log_info "Keycloak protocol mapper for client ${1} already exists. Skipping it's creation"
    fi

    # Map the above client scope id to the client
    kubectl -n ${kcNamespace} exec ${kcPod} --container ${kcContainer} -- \
        ${kcAdmCli}  update clients/${1}/default-client-scopes/${2}

}