#!/bin/bash -x
set -euo pipefail

export numUsersToCreate=$(jq -r '.config.additionalUsers[].firstname' ${installationWorkspace}/users.json | wc -l)
export kcRealm=${baseDomain}
export ldapDn=$(sudo slapcat | grep dn | head -1 | cut -f2 -d' ')
export kcInternalUrl=http://localhost:8080
export kcBinDir=/opt/jboss/keycloak/bin/
export kcAdmCli=/opt/jboss/keycloak/bin/kcadm.sh
export kcPod=$(kubectl get pods -l 'app.kubernetes.io/name=keycloak' -n keycloak --output=json | jq -r '.items[].metadata.name')

newGid=""

if [[ ${numUsersToCreate} -ne 0 ]]; then
    for i in $(seq 0 $((numUsersToCreate - 1))); do
        echo "i: $i"
        firstname=$(jq -r '.config.additionalUsers['$i'].firstname' ${installationWorkspace}/users.json)
        surname=$(jq -r '.config.additionalUsers['$i'].surname' ${installationWorkspace}/users.json)
        email=$(jq -r '.config.additionalUsers['$i'].email' ${installationWorkspace}/users.json)
        defaultUserKeyboardLanguage=$(jq -r '.config.additionalUsers['$i'].keyboard_language' ${installationWorkspace}/users.json)
        userRole=$(jq -r '.config.additionalUsers['$i'].role' ${installationWorkspace}/users.json)

        firstnameSubstringLength=$((8 - ${#surname}))

        if [[ ${firstnameSubstringLength} -le 0 ]]; then
            firstnameSubstringLength=1
        fi
        echo $firstnameSubstringLength
        userid="$(echo ${surname,,} | cut -c1-7)$(echo ${firstname,,} | cut -c1-${firstnameSubstringLength})"

        echo "${userid} ${firstname} ${surname} ${email}"

        if ! id -u ${userid} > /dev/null 2>&1; then

            if [ ! -f /home/${userid}/.ssh/id_rsa ]; then
                # Create the kx.hero user ssh directory.
                sudo mkdir -pm 700 /home/${userid}/.ssh

                # Ensure the permissions are set correct
                for i in {1..10}; do
                    echo "i: $i"
                    sudo chown -R ${userid}:${userid} /home/${userid}/.ssh || true
                    if [[ $(stat -c '%u' /home/${userid}/.ssh) -eq ${newGid} ]]; then
                        break
                    else
                        sleep 10
                    fi
                done

            fi

            # Generate password
            if [ -f ${sharedKxHome}/.users.json ]; then 
                if [ -z $(cat ${sharedKxHome}/.users.json | jq -r '.[] | select(.user=="'${userid}'") | .user' || true) ]; then
                    generatedPassword=$(pwgen -1s 8)
                    echo "[ { \"user\": \"${userid}\", \"password\": \"${generatedPassword}\" } ]" | sudo tee ${sharedKxHome}/.temp.users.json
                    cat /usr/share/kx.as.code/.users.json /usr/share/kx.as.code/.temp.users.json | jq -s add | tee /usr/share/kx.as.code/.users.json
                    rm tee ${sharedKxHome}/.temp.users.json
                else
                    generatedPassword=$(cat ${sharedKxHome}/.users.json | jq -r '.[] | select(.user=="'${userid}'") | .password')
                fi
            else
                generatedPassword=$(pwgen -1s 8)
                echo "[ { \"user\": \"${userid}\", \"password\": \"${generatedPassword}\" } ]" | sudo tee ${sharedKxHome}/.users.json
            fi

            # Determine UID/GID for new user
            lastLdapGid=$(sudo ldapsearch -x -b "ou=People,${ldapDn}" | grep gidNumber | sed 's/gidNumber: //' | sort | uniq | tail -1)
            echo "Last GID: $lastLdapGid"
            newGid=$((lastLdapGid + 1))
            echo "New GID: $newGid"

            # Add User Group to OpenLDAP for Linux login
            if ! sudo ldapsearch -x -b "cn=${userid},ou=Groups,ou=People,${ldapDn}"; then
            echo '''
      dn: cn='${userid}',ou=Groups,ou=People,'${ldapDn}'
      objectClass: posixGroup
      cn: '${userid}'
      gidNumber: '${newGid}'
      ''' | sed -e 's/^[ \t]*//' | sed '/^$/d' | sudo tee /etc/ldap/users_group_${userid}.ldif
            sudo ldapadd -D "cn=admin,${ldapDn}" -w "${vmPassword}" -H ldapi:/// -f /etc/ldap/users_group_${userid}.ldif
            fi

            # Add User to OpenLDAP
            if ! sudo ldapsearch -x -b "uid=${userid},ou=Users,ou=People,${ldapDn}"; then
            echo '''
      dn: uid='${userid}',ou=Users,ou=People,'${ldapDn}'
      objectClass: top
      objectClass: posixAccount
      objectClass: shadowAccount
      objectClass: inetOrgPerson
      objectClass: organizationalPerson
      objectClass: person
      cn: '${userid}'
      sn: '${userid}'
      uid: '${userid}'
      uidNumber: '${newGid}'
      gidNumber: '${newGid}'
      homeDirectory: /home/'${userid}'
      userPassword: '${generatedPassword}'
      mail: '${email}'
      loginShell: /bin/zsh
      ''' | sed -e 's/^[ \t]*//' | sed '/^$/d' | sudo tee /etc/ldap/new_user_${userid}.ldif
            sudo ldapadd -D "cn=admin,${ldapDn}" -w "${vmPassword}" -H ldapi:/// -f /etc/ldap/new_user_${userid}.ldif
            fi
            
            # Restart NSLCD and NSCD to make new users available for logging in
            sudo systemctl restart nslcd.service
            sudo systemctl restart nscd.service

            # Test for user availability
            for i in {1..10}; do
                echo "i: $i"
                if [[ -n $(sudo -H -i -u ${userid} sh -c 'id' || true) ]]; then
                    break
                else
                    sleep 10
                fi
            done

            # Check new user user via getent and ldapsearch
            if [[ -z ${newGid} ]]; then
                sudo getent passwd | grep ${userid} # Check ldap user is active, ie. shows up with getent
                sudo getent group | grep ${userid} # Check ldap group is active, ie. shows up with getent
                newGid=$(id -g ${userid})
            else
                sudo getent passwd | grep ${newGid} # Check ldap user is active, ie. shows up with getent
                sudo getent group | grep ${newGid} # Check ldap group is active, ie. shows up with getent
            fi
            sudo ldapsearch -x -b "ou=People,${ldapDn}"

            # Create "groupOfNames" group for Keycloak if it does not already exist
            kcadminGroupExists=$(sudo ldapsearch -H ldapi:/// -Y EXTERNAL -LLL -b "${ldapDn}" cn=kcadmins 2> /dev/null)
            if [[ -z ${kcadminGroupExists} ]]; then
                # Create kcadmins group with new user
                echo '''
        dn: cn=kcadmins,ou=Groups,ou=People,'${ldapDn}'
        objectClass: groupOfNames
        cn: kcadmins
        member: uid='${userid}',ou=Users,ou=People,'${ldapDn}'
        ''' | sed -e 's/^[ \t]*//' | sed '/^$/d' | sudo tee /etc/ldap/create-groupOfNames-group.ldif
                sudo ldapadd -D "cn=admin,${ldapDn}" -w "${vmPassword}" -H ldapi:/// -f /etc/ldap/create-groupOfNames-group.ldif
            else
                if ! sudo ldapsearch -x -b "cn=kcadmins,ou=Groups,ou=People,${ldapDn}" '(&(objectClass=groupOfNames)(member=uid='${userid}',ou=Users,ou=People,'${ldapDn}'))' | grep -q ^dn:; then
                # Add user to existing kcadmins group
                echo '''
            dn: uid='${userid}',ou=Users,ou=People,'${ldapDn}'
            changetype: modify
            add: memberOf
            memberOf: cn=kcadmins,ou=Groups,ou=People,'${ldapDn}'
            ''' | sed -e 's/^[ \t]*//' | sed '/^$/d' | sudo tee /etc/ldap/add_user_${userid}_to_kcadmins.ldif
                    sudo ldapadd -D "cn=admin,${ldapDn}" -w "${vmPassword}" -H ldapi:/// -f /etc/ldap/add_user_${userid}_to_kcadmins.ldif
                fi
            fi

            # Check user was added successfully
            ldapsearch -H ldapi:/// -Y EXTERNAL -LLL -b "${ldapDn}" memberOf 2> /dev/null | grep memberOf

            # Give user root priviliges
            printf "${userid}        ALL=(ALL)       NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers

        fi

        # Create user's desktop folder
        sudo mkdir -p /home/${userid}/Desktop

        # Add desktop shortcuts for all users
        if sudo test -f /home/${userid}/Desktop/"KX.AS.CODE Source"; then
            sudo ln -s ${sharedGitHome}/kx.as.code /home/${userid}/Desktop/"KX.AS.CODE Source"
        fi

        # Add admin tools folder to desktop if user has admin role
        if [[ "${userRole}" == "admin" ]]; then
            if sudo test -f /home/${userid}/Desktop/"${adminShortcutsDirectory}"; then
                ln -s "${adminShortcutsDirectory}" /home/${userid}/Desktop/
            fi
        fi

        # Copy all file to user
        sudo cp -rfT ${installationWorkspace}/skel /home/${userid}
        sudo rm -rf /home/${userid}/.cache/sessions

        # Set default keyboard language as per users.json
        keyboardLanguages=""
        availableLanguages="us de gb fr it es"
        for language in ${availableLanguages}; do
            if [[ -z ${keyboardLanguages} ]]; then
                keyboardLanguages="${language}"
            else
                if [[ ${language} == "${defaultUserKeyboardLanguage}" ]]; then
                    keyboardLanguages="${language},${keyboardLanguages}"
                else
                    keyboardLanguages="${keyboardLanguages},${language}"
                fi
            fi
        done

        if sudo test -f /home/${userid}/.config/autostart/keyboard-language.desktop; then
        echo """[Desktop Entry]
    Type=Application
    Name=SetKeyboardLanguage
    Exec=setxkbmap ${keyboardLanguages} -option grp:alt_shift_toggle
    """ | sudo tee /home/${userid}/.config/autostart/keyboard-language.desktop
    fi

        # Assign random avatar to user
        ls /usr/share/avatars/avatar_*.png | sort -R | tail -1 | while read file; do
            if sudo test -f /home/${userid}/.face.icon; then
                sudo cp -f $file /home/${userid}/.face.icon
            fi
        done
        
        # Loop change ownership to wait for OpenLDAP user to be available for setting ownership
        newGid=$(id -g ${userid}) # In case script is re-run and the variable not set as a result
        for i in {1..10}; do
            echo "i: $i"
            sudo chown -f -R ${newGid}:${newGid} /home/${userid} || true
            if [[ $(stat -c '%u' /home/${userid} || true) -eq ${newGid} ]]; then
                break
            else
                sleep 10
            fi
        done

        # Add KX.AS.CODE Root CA cert to Chrome CA Store
        if [ ! -f /home/${userid}/.pki/nssdb ]; then
            sudo rm -rf /home/${userid}/.pki
            mkdir -p /home/${userid}/.pki/nssdb/
            chown -R ${newGid}:${newGid} /home/${userid}/.pki
            sudo -H -i -u ${userid} sh -c "certutil -N --empty-password -d sql:/home/${userid}/.pki/nssdb"
            sudo -H -i -u ${userid} sh -c "/usr/local/bin/trustKXRootCAs.sh"
            sudo -H -i -u ${userid} sh -c "certutil -L -d sql:/home/${userid}/.pki/nssdb"
        fi

        # Create SSH key kx.hero user
        sudo chmod 700 /home/${userid}/.ssh
        sudo -H -i -u ${userid} sh -c "yes | ssh-keygen -f ssh-keygen -m PEM -t rsa -b 4096 -q -f /home/${userid}/.ssh/id_rsa -N ''"

	# Create Kubeconfig file
	sudo mkdir -p /home/${userid}/.kube
	sudo cat /etc/kubernetes/admin.conf | sed '/users:/,$d' | sed 's/kubernetes-admin/oidc/g' | sudo tee /home/${userid}/.kube/config
	sudo chown -R ${userid}:${userid} /home/${userid}/.kube
	sudo chmod 400 /home/${userid}/.kube/config

        # Set credential token in new Realm
        kubectl -n keycloak exec ${kcPod} -- \
            ${kcAdmCli} config credentials --server ${kcInternalUrl}/auth --realm ${kcRealm} --user admin --password ${vmPassword} --client admin-cli

        # Enable Keycloak OIDC for new user
        sudo -H -i -u ${userid} sh -c "${installationWorkspace}/client-oidc-setup.sh"
        
        export kcUserId=$(kubectl -n keycloak exec ${kcPod} -- \
            ${kcAdmCli} get users -r ${kcRealm} -q username=${userid} | jq -r '.[].id')
        
        sudo -H -i -u ${userid} sh -c "kubectl config set-context --current --user=oidc"
        
        sudo kubectl get clusterrolebinding oidc-cluster-admin-${userid} || \
            sudo kubectl create clusterrolebinding oidc-cluster-admin-${userid} --clusterrole=cluster-admin --user='https://keycloak.'${baseDomain}'/auth/realms/'${kcRealm}'#'${kcUserId}''

        # Create and configure XRDP connection in Guacamole database
        if [[ -z "$(sudo su - postgres -c 'psql -U postgres -d guacamole_db -c "select * FROM guacamole_entity WHERE name = '${userid}' AND guacamole_entity.type = 'USER';"')" ]]; then
        echo """
    INSERT INTO guacamole_entity (name, type) VALUES ('${userid}', 'USER');
    INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
    SELECT
        entity_id,
        decode('CA458A7D494E3BE824F5E1E175A1556C0F8EEF2C2D7DF3633BEC4A29C4411960', 'hex'),  -- '${generatedPassword}'
        decode('FE24ADC5E11E2B25288D1704ABE67A79E342ECC26064CE69C5B3177795A82264', 'hex'),
        CURRENT_TIMESTAMP
    FROM guacamole_entity WHERE name = '${userid}' AND guacamole_entity.type = 'USER';

    -- Grant admin permission to read/update/administer self
    INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
    SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission::guacamole_object_permission_type
    FROM (
        VALUES
            ('${userid}', '${userid}', 'READ'),
            ('${userid}', '${userid}', 'UPDATE'),
            ('${userid}', '${userid}', 'ADMINISTER')
    ) permissions (username, affected_username, permission)
    JOIN guacamole_entity          ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
    JOIN guacamole_entity affected ON permissions.affected_username = affected.name AND guacamole_entity.type = 'USER'
    JOIN guacamole_user            ON guacamole_user.entity_id = affected.entity_id;
    """ | sudo su - postgres -c "psql -U postgres -d guacamole_db" -

        # Create and configure XRDP connection in Guacamole database
        echo """

    INSERT INTO public.guacamole_connection_group_permission(entity_id, connection_group_id, permission)
    VALUES (
      (select entity_id from guacamole_entity where name = '${userid}'),
      (select connection_group_id from guacamole_connection_group where connection_group_name = 'kx-as-code'),
      'READ'
    );

    INSERT INTO public.guacamole_connection_permission(entity_id, connection_id, permission)
    VALUES (
      (select entity_id from guacamole_entity where name = '${userid}'),
      (select connection_id from guacamole_connection where connection_name = 'rdp'),
      'READ'
    );

    """ | sudo su - postgres -c "psql -U postgres -d guacamole_db" -
    fi

    done
fi
