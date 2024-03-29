#!/bin/bash

# Ensure Kubernetes is available before proceeding to the next step
# shellcheck disable=SC2016
kubernetesHealthCheck

# Check application is reachable before continuing
checkUrlHealth "https://${componentName}.${baseDomain}" "200"

# Set Keycloak credential for upcoming API calls
for i in {1..50}; do
  # Check if Keycloak is ready to receive requests, else wait and try again
  if (($(kubectl get pods -l 'app.kubernetes.io/name=keycloak' -n ${namespace} -o json | jq '.items[].status.containerStatuses[].ready' | wc -l))); then
    # Get Keycloak POD name for subsequent Keycloak CLI commands
    sourceKeycloakEnvironment
    kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
      ${kcAdmCli} config credentials --server ${kcInternalUrl}/auth --realm master --user admin --password ${keycloakAdminPassword} --client admin-cli
    break
  else
    sleep 15
  fi
done

# Create KX.AS.CODE Realm
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get realms | jq -r '.[] | select(.realm=="'${kcRealm}'") | .realm') ]]; then
  # Create new Realm
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcAdmCli} create realms -s realm=${kcRealm} -s enabled=true -o
else
  # Export current realm setup
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get realms | jq '.[] | select(.realm=="'${kcRealm}'")' | /usr/bin/sudo tee ${installationWorkspace}/keycloak_realm_${kcRealm}.json
fi

# Create Admin User in KX.AS.CODE Realm
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get users -r ${kcRealm} | jq -r '.[] | select(.username=="admin") | .username') ]]; then
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcBinDir}/add-user-keycloak.sh -r ${kcRealm} -u admin -p ${keycloakAdminPassword}
fi

# Reload JBoss Instance
kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
  /opt/jboss/keycloak/bin/jboss-cli.sh --connect --commands=:reload

# Get credential token in new Realm
kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
  ${kcAdmCli} config credentials --server ${kcInternalUrl}/auth --realm ${kcRealm} --user admin --password ${keycloakAdminPassword} --client admin-cli

# Give new admin user a password
kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
  ${kcAdmCli} set-password --realm ${kcRealm} --username admin --new-password ${keycloakAdminPassword}

# Create Admins Group
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get groups -r ${kcRealm} | jq -r '.[] | select(.name=="admins") | .name') ]]; then
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcAdmCli} create groups --realm ${kcRealm} -s name=admins
fi

# Create Users Group
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get groups -r ${kcRealm} | jq -r '.[] | select(.name=="users") | .name') ]]; then
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcAdmCli} create groups --realm ${kcRealm} -s name=users
fi

# Function to check if roles already assigned to group, assign if not
function assignRole() {
  roleAssigned=$(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get-roles -r ${kcRealm} --cclientid realm-management --gname ${2} | jq -r '.[] | select(.name=="'${1}'") | .name' || true)
  if [[ -z ${roleAssigned} ]]; then
    kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
      ${kcAdmCli} add-roles --realm ${kcRealm} --gname ${2} --cclientid realm-management \
      --rolename ${1}
  fi
}

userAssignedRoles="query-realms view-realm query-clients view-identity-providers view-events query-groups query-users view-users view-authorization view-clients"
for role in ${userAssignedRoles}; do
  echo assignRole "${role}" "users"
  assignRole "${role}" "users"
done

adminAssignedRoles="manage-events manage-identity-providers realm-admin query-realms view-realm manage-users impersonation create-client query-clients view-identity-providers view-events query-groups query-users manage-clients view-users manage-realm manage-authorization view-clients"
for role in ${adminAssignedRoles}; do
  echo assignRole "${role}" "admins"
  assignRole "${role}" "admins"
done

# Set CLI credentials for Realm
kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
  ${kcAdmCli} config credentials --server ${kcInternalUrl}/auth --realm ${kcRealm} --user admin --password ${keycloakAdminPassword} --client admin-cli

# Obtain Realm Id
kcParentId=$(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
  ${kcAdmCli} get / --fields id --format csv --noquotes)

# Update authentication flow to enable MFA before user import from LDAP
keycloakUpdateRequiredActionsAuthFlow

# Get LDAP Admin Password
export ldapAdminPassword=$(getPassword "openldap-admin-password" "openldap")

# Create LDAP User Federation
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get components -r ${kcRealm} | jq -r '.[] | select(.providerId=="ldap") | .name') ]]; then
  ldapProviderId=$(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcAdmCli} create components --realm ${kcRealm} \
    -s name=ldap-provider \
    -s providerId=ldap \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s parentId=${kcParentId} \
    -s 'config.priority=["1"]' \
    -s 'config.fullSyncPeriod=["86400"]' \
    -s 'config.changedSyncPeriod=["600"]' \
    -s 'config.cachePolicy=["DEFAULT"]' \
    -s 'config.batchSizeForSync=["1000"]' \
    -s 'config.editMode=["WRITABLE"]' \
    -s 'config.syncRegistrations=["false"]' \
    -s 'config.vendor=["other"]' \
    -s 'config.usernameLDAPAttribute=["uid"]' \
    -s 'config.rdnLDAPAttribute=["uid"]' \
    -s 'config.uuidLDAPAttribute=["uid"]' \
    -s 'config.userObjectClasses=["posixAccount"]' \
    -s 'config.connectionUrl=["ldap://ldap.'${baseDomain}':389"]' \
    -s 'config.usersDn=["ou=Users,ou=People,'${ldapDn}'"]' \
    -s 'config.authType=["simple"]' \
    -s 'config.bindDn=["cn=admin,'${ldapDn}'"]' \
    -s 'config.bindCredential=["'${ldapAdminPassword}'"]' \
    -s 'config.searchScope=["1"]' \
    -s 'config.useTruststoreSpi=["ldapsOnly"]' \
    -s 'config.connectionPooling=["true"]' \
    -s 'config.pagination=["true"]' \
    -i)
fi

# Add Group Mapper
if [[ ! $(kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- ${kcAdmCli} get components -r ${kcRealm} | jq -r '.[] | select(.providerId=="group-ldap-mapper") | .name') ]]; then
  kubectl -n ${namespace} exec ${kcPod} --container ${kcContainer} -- \
    ${kcAdmCli} create components --realm ${kcRealm} \
    -s name=group-ldap-mapper \
    -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
    -s parentId=${ldapProviderId} \
    -s 'config."groups.dn"=["ou=Groups,ou=People,'${ldapDn}'"]' \
    -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["groupOfNames"]' \
    -s 'config."preserve.group.inheritance"=["true"]' \
    -s 'config."membership.ldap.attribute"=["member"]' \
    -s 'config."membership.attribute.type"=["DN"]' \
    -s 'config."groups.ldap.filter"=["(&(objectClass=groupOfNames)(cn=kcadmins))"]' \
    -s 'config.mode=["LDAP_ONLY"]' \
    -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' \
    -s 'config."mapped.group.attributes"=["admins"]' \
    -s 'config."drop.non.existing.groups.during.sync"=["false"]' \
    -s 'config.roles=["admins"]' \
    -s 'config.groups=["admins"]' \
    -s 'config.group=[]' \
    -s 'config.preserve=["true"]' \
    -s 'config.membership=["member"]'
fi
