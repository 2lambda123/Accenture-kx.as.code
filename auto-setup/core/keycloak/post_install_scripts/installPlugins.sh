#!/bin/bash -x

# Set variables
export kcRealm=${baseDomain}
export ldapDn=$(sudo slapcat | grep dn | head -1 | cut -f2 -d' ')
export kcInternalUrl=http://localhost:8080
export kcBinDir=/opt/jboss/keycloak/bin/
export kcAdmCli=/opt/jboss/keycloak/bin/kcadm.sh
export kcPod=$(kubectl get pods -l 'app.kubernetes.io/name=keycloak' -n keycloak --output=json | jq -r '.items[].metadata.name')

# Install Krew for installing kauthproxy and kubelogin
(
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/' -e 's/aarch64$/arm64/')" &&
  "$KREW" install krew
)

# Put Krew on the path before calling it
cp /root/.krew/bin/kubectl-krew /usr/local/bin

# Install OIDC Login and KauthProxy
sudo kubectl krew install auth-proxy oidc-login

# Make plugins available to all
cp /root/.krew/bin/kubectl-* /usr/local/bin

export kcPod=$(kubectl get pods -l 'app.kubernetes.io/name=keycloak' -n ${namespace} --output=json | jq -r '.items[].metadata.name')

# Get credential token in new Realm
kubectl -n ${namespace} exec ${kcPod} -- \
  ${kcAdmCli} config credentials --server ${kcInternalUrl}/auth --realm ${kcRealm} --user admin --password ${vmPassword} --client admin-cli

clientId=$(kubectl -n ${namespace} exec ${kcPod} -- \
  ${kcAdmCli} get clients -r ${kcRealm} --fields id,clientId | jq -r '.[] | select(.clientId=="kubernetes") | .id')

clientSecret=$(kubectl -n ${namespace} exec ${kcPod} -- \
  ${kcAdmCli} get clients/${clientId}/client-secret | jq -r '.value')

# Create setup script for new users
echo '''
#!/bin/bash
kubectl config set-credentials oidc \
	  --exec-api-version=client.authentication.k8s.io/v1beta1 \
	  --exec-command=kubectl \
	  --exec-arg=oidc-login \
	  --exec-arg=get-token \
	  --exec-arg=--oidc-issuer-url=https://'${componentName}'.'${baseDomain}'/auth/realms/'${kcRealm}' \
	  --exec-arg=--oidc-client-id=kubernetes \
	  --exec-arg=--oidc-client-secret='${clientSecret}'
''' | sudo tee ${installationWorkspace}/client-oidc-setup.sh
sudo chmod 755 ${installationWorkspace}/client-oidc-setup.sh

