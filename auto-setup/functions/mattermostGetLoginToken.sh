mattermostGetLoginToken() {

    if checkApplicationInstalled "mattermost" "collaboration"; then

        mattermostUser=${1}

        # Get Password
        mattermostPassword=$(managedPassword "mattermost-${mattermostUser}-password" "mattermost")

        # Get Login Token
        curl -s -i -d '{"login_id":"'${mattermostUser}'@'${baseDomain}'","password":"'${mattermostPassword}'"}' https://mattermost.${baseDomain}/api/v4/users/login | grep 'token' | sed 's/token: //g' | sed "s/[^[:alnum:]-]//g"

    fi

}
