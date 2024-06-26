harborGetProjectId() {

        if checkApplicationInstalled "harbor" "cicd"; then

        harborProjectName=${1}

        # Get Harbor Admin Password
        export harborAdminPassword=$(managedApiKey "harbor-admin-password" "harbor")

        # Get Harbor Project Id via API
        curl -s -u 'admin:'${harborAdminPassword}'' -X GET https://${componentName}.${baseDomain}/api/v2.0/projects | jq -r '.[] | select(.name=="'${harborProjectName}'") | .project_id'

    fi

}
