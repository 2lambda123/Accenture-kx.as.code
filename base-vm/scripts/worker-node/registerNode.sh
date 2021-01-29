#!/bin/bash -x

. /etc/environment

# Install nvme-cli if running on host with NVMe block devices (for example on AWS with EBS)
sudo lsblk -i -o kname,mountpoint,fstype,size,maj:min,name,state,rm,rota,ro,type,label,model,serial
nvme_cli_needed=$(df -h | grep "nvme")
if [[ -n "nvme_cli_needed" ]]; then
  # For AWS
  sudo apt install -y nvme-cli lvm2
  drives=$(lsblk -i -o kname,mountpoint,fstype,size,type | grep disk | awk {'print $1'})
  for drive in ${drives}
  do
    partitions=$(lsblk -i -o kname,mountpoint,fstype,size,type | grep ${drive} | grep part)
    if [[ -z ${partitions} ]]; then
      export driveB="${drive}"
      export partition="p1"
      break
    fi
  done
else
  # For VirtualBox, VNWare etc
  export driveB="sdb"
  export partition="1"
fi

echo "${driveB}" | sudo tee /home/${vmUser}/.config/kx.as.code/driveB
cat /home/${vmUser}/.config/kx.as.code/driveB

TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
# Define base variables
export vmPassword=$(cat /home/${vmUser}/.config/kx.as.code/.user.cred)
export installationWorkspace=/home/${vmUser}/Kubernetes
export autoSetupHome=/home/${vmUser}/Documents/kx.as.code_source/auto-setup

# Check autoSetup.json file is present before starting script
timeout -s TERM 6000 bash -c \
'while [[ ! -f '${installationWorkspace}'/autoSetup.json ]];\
do echo "Waiting for '${installationWorkspace}'/autoSetup.json file" && sleep 15;\
done'

# Get number of local volumes to pre-provision
export number1gbVolumes=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.local_volumes.one_gb')
export number5gbVolumes=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.local_volumes.five_gb')
export number10gbVolumes=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.local_volumes.ten_gb')
export number30gbVolumes=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.local_volumes.thirty_gb')
export number50gbVolumes=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.local_volumes.fifty_gb')

# Check logical partitions
sudo lvs
sudo df -hT
sudo lsblk

# Create full partition on /dev/${driveB}
echo 'type=83' | sudo sfdisk /dev/${driveB}

sudo pvcreate /dev/${driveB}${partition}
sudo vgcreate k8s_local_vol_group /dev/${driveB}${partition}

BASE_K8S_LOCAL_VOLUMES_DIR=/mnt/k8s_local_volumes

create_volumes() {
  if [[ ${2} -ne 0 ]]; then
    for i in $(eval echo "{1..$2}")
    do
        sudo lvcreate -L ${1} -n k8s_${1}_local_k8s_volume_${i} k8s_local_vol_group
        sudo mkfs.xfs /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i}
        sudo mkdir -p ${BASE_K8S_LOCAL_VOLUMES_DIR}/k8s_${1}_local_k8s_volume_${i}
        sudo mount /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} ${BASE_K8S_LOCAL_VOLUMES_DIR}/k8s_${1}_local_k8s_volume_${i}
        if [[ -f /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} ]]; then
          sudo echo '/dev/k8s_local_vol_group/k8s_'${1}'_local_k8s_volume_'${i}' '${BASE_K8S_LOCAL_VOLUMES_DIR}'/k8s_'${1}'_local_k8s_volume_'${i}' xfs defaults 0 0' | sudo tee -a /etc/fstab
        else
          echo "/dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} does not exist. Not adding to /etc/fstab. Possible reason is that there was not enough space left on the drive to create it"
        fi
    done
  fi
}

create_volumes "1G" ${number1gbVolumes}
create_volumes "5G" ${number5gbVolumes}
create_volumes "10G" ${number10gbVolumes}
create_volumes "30G" ${number30gbVolumes}
create_volumes "50G" ${number50gbVolumes}

# Check logical partitions
sudo lvs
sudo df -hT
sudo lsblk

cd ${installationWorkspace}

# Get configs from autoSetup.json
export virtualizationType=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.virtualizationType')
export nicPrefix=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.nic_names.'${virtualizationType}'')
export netDevice=$(nmcli device show | grep -E 'enp|ens' | grep 'GENERAL.DEVICE' | awk '{print $2}')
export environmentPrefix=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.environmentPrefix')
if [ -z ${environmentPrefix} ]; then
    export baseDomain="$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseDomain')"
else
    export baseDomain="${environmentPrefix}.$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseDomain')"
fi
export defaultKeyboardLanguage=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.defaultKeyboardLanguage')
export baseUser=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseUser')
export basePassword=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.basePassword')
export baseIpType=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseIpType')
export baseIpRangeStart=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseIpRangeStart')
export baseIpRangeEnd=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.baseIpRangeEnd')

# Get proxy settings
export httpProxySetting=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.proxy_settings.http_proxy')
export httpsProxySetting=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.proxy_settings.https_proxy')
export noProxySetting=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.proxy_settings.no_proxy')

# Get fixed IPs if defined
if [ "${baseIpType}" == "static" ]; then
  export fixedIpHosts=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.baseFixedIpAddresses | keys[]')
  for fixIpHost in ${fixedIpHosts}
  do
      fixIpHostVariableName=$(echo ${fixIpHost} | sed 's/-/__/g')
      export ${fixIpHostVariableName}_IpAddress="$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.baseFixedIpAddresses."'${fixIpHost}'"')"
  done
  export fixedNicConfigGateway=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.gateway')
  export fixedNicConfigDns1=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.dns1')
  export fixedNicConfigDns2=$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.dns2')
fi

if [[ "${baseIpType}" == "static" ]]; then
  if [[ -z "$(cat /etc/resolv.conf | grep \\"${fixedNicConfigDns1}\\")" ]]; then

      # Prevent DHCLIENT updating static IP
      echo "supersede domain-name-servers ${fixedNicConfigDns1}, ${fixedNicConfigDns2};" | sudo tee -a /etc/dhcp/dhclient.conf
      echo '''
      #!/bin/sh
      make_resolv_conf(){
          :
      }
      ''' | sed -e 's/^[ \t]*//' | sed 's/:/    :/g' | sudo tee /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate
      sudo chmod +x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

      # Change DNS resolution to allow wildcards for resolving deployed K8s services
      echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf
      sudo systemctl restart systemd-resolved
      sudo rm -f /etc/resolv.conf

      # Update DNS Entry for hosts if ip type set to static
      if [ "${baseIpType}" == "static" ]; then
          export kxMainIp="$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.baseFixedIpAddresses."kx-main"')"
          export kxWorkerIp="$(cat ${installationWorkspace}/autoSetup.json | jq -r '.config.staticNetworkSetup.baseFixedIpAddresses."'$(hostname)'"')"
      fi

      # Create resolv.conf for desktop user with for resolving local domain with DNSMASQ
      echo '''
      # File Generated During KX.AS.CODE initialization
      nameserver '${fixedNicConfigDns1}'
      nameserver '${fixedNicConfigDns2}'
      ''' | sed -e 's/^[ \t]*//' | sudo tee /etc/resolv.conf

      # Configure IF to be managed/confgured by network-manager
      sudo rm -f /etc/NetworkManager/system-connections/*
      sudo mv /etc/network/interfaces /etc/network/interfaces.unused
      sudo nmcli con add con-name "${netDevice}" ifname ${netDevice} type ethernet ip4 ${kxWorkerIp}/24 gw4 ${fixedNicConfigGateway}
      sudo nmcli con mod "${netDevice}" ipv4.method "manual"
      sudo nmcli con mod "${netDevice}" ipv4.dns "${fixedNicConfigDns1},${fixedNicConfigDns2}"
      sudo systemctl restart network-manager
      sudo nmcli con up "${netDevice}"

  fi
fi

# Try to get KX-Main IP address via a lookup if baseIpType is set to dynamic
 if [ "${baseIpType}" == "dynamic" ]; then
   # Read the file dropped by Terraform
  export kxMainIp=$(cat /home/${vmUser}/Kubernetes/kxMainIpAddress)
fi

# Wait until network and DNS resolution is back up. Also need to wait for kx-main, in case the worker node comes up first
timeout -s TERM 3000 bash -c 'while [[ "$rc" != "0" ]];         do
nslookup kx-main.'${baseDomain}'; rc=$?;
echo "Waiting for kx-main DNS resolution to function" && sleep 5;         done'

KUBEDIR=/home/${vmUser}/Kubernetes
mkdir -p ${KUBEDIR}
chown -R ${vmUser}:${vmUser} ${KUBEDIR}

if [[ "${virtualizationType}" != "aws" ]]; then
  # Create RSA key for kx.hero user
  mkdir -p /home/${vmUser}/.ssh
  chown -R ${vmUser}:${vmUser} /home/${vmUser}/.ssh
  chmod 700 /home/${vmUser}/.ssh
  yes | sudo -u ${vmUser} ssh-keygen -f ssh-keygen -m PEM -t rsa -b 4096 -q -f /home/${vmUser}/.ssh/id_rsa -N ''

  # Add key to KX-Main host
  sudo -H -i -u ${vmUser} bash -c "sshpass -f /home/${vmUser}/.config/kx.as.code/.user.cred ssh-copy-id -o StrictHostKeyChecking=no ${vmUser}@${kxMainIp}"

  # Add KX-Main key to worker
  sudo -H -i -u ${vmUser} bash -c "ssh -o StrictHostKeyChecking=no ${vmUser}@${kxMainIp} \"cat /home/$vmUser/.ssh/id_rsa.pub\" | tee -a /home/$vmUser/.ssh/authorized_keys"
  sudo mkdir -p /root/.ssh
  sudo chmod 700 /root/.ssh
  sudo cp /home/$vmUser/.ssh/authorized_keys /root/.ssh/
fi
# Copy KX.AS.CODE CA certificates from main node and restart docker
export REMOTE_KX_MAIN_KUBEDIR=/home/$vmUser/Kubernetes
export REMOTE_KX_MAIN_CERTSDIR=$REMOTE_KX_MAIN_KUBEDIR/certificates

CERTIFICATES="kx_root_ca.pem kx_intermediate_ca.pem"

## Wait for certificates to be available on KX-Main
wait-for-certificate() {
        timeout -s TERM 3000 bash -c 'while [[ ! -f /home/'${vmUser}'/Kubernetes/'${CERTIFICATE}' ]];         do
        sudo -H -i -u '${vmUser}' bash -c "scp -o StrictHostKeyChecking=no '${vmUser}'@'${kxMainIp}':'${REMOTE_KX_MAIN_CERTSDIR}'/'${CERTIFICATE}' /home/'${vmUser}'/Kubernetes";
        echo "Waiting for ${0}" && sleep 5;         done'
}

sudo mkdir -p /usr/share/ca-certificates/kubernetes
for CERTIFICATE in ${CERTIFICATES}
do
        wait-for-certificate ${CERTIFICATE}
        sudo cp /home/${vmUser}/Kubernetes/${CERTIFICATE} /usr/share/ca-certificates/kubernetes/
        echo "kubernetes/${CERTIFICATE}" | sudo tee -a /etc/ca-certificates.conf
done

# Install Root and Intermediate Root CA Certificates into System Trust Store
sudo update-ca-certificates --fresh

# Restart Docker to pick up the new KX.AS.CODE CA certificates
sudo systemctl restart docker

# Wait for Kubernetes to be available
wait-for-url() {
        timeout -s TERM 3000 bash -c \
        'while [[ "$(curl -k -s ${0})" != "ok" ]];\
        do echo "Waiting for ${0}" && sleep 5;\
        done' ${1}
        curl -k $1
}
wait-for-url https://${kxMainIp}:6443/livez

# Kubernetes master is reachable, join the worker node to cluster
sudo -H -i -u ${vmUser} bash -c "ssh -o StrictHostKeyChecking=no $vmUser@${kxMainIp} 'kubeadm token create --print-join-command 2>/dev/null'" > ${KUBEDIR}/kubeJoin.sh
sudo chmod 755 ${KUBEDIR}/kubeJoin.sh
sudo ${KUBEDIR}/kubeJoin.sh

# Disable the Service After it Ran
sudo systemctl disable k8s-register-node.service

# Fix reliance on non existent file: /run/systemd/resolve/resolv.conf
sudo sed -i '/^\[Service\]/a Environment="KUBELET_EXTRA_ARGS=--resolv-conf=\/etc\/resolv.conf"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Setup proxy settings if they exist
if [[ -n ${httpProxySetting} ]] || [[ -n ${httpsProxySetting} ]]; then
  if [[ "${httpProxySetting}" != "null" ]] || [[ "${httpsProxySetting}" != "null" ]]; then

    if [[ "${httpProxySetting}" == "null" ]]; then
      httpProxySetting=${httpsProxySetting}
    fi
    httpProxySettingBase=$(echo ${httpProxySetting} | sed 's/https:\/\///g' | sed 's/http:\/\///g')

    if [[ "${httpsProxySetting}" == "null" ]]; then
      httpsProxySetting=${httpProxySetting}
    fi
    httpsProxySettingBase=$(echo ${httpsProxySetting} | sed 's/https:\/\///g' | sed 's/http:\/\///g')

    echo '''
    [Service]
    Environment="HTTP_PROXY='${httpProxySettingBase}'/" "HTTPS_PROXY='${httpsProxySettingBase}'/" "NO_PROXY=localhost,127.0.0.1,.'${baseDomain}'"
    ''' | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf

    systemctl daemon-reload
    systemctl restart docker

    baseip=$(echo ${kxWorkerIp} | cut -d'.' -f1-3)

    echo '''
    export http_proxy='${httpProxySetting}'
    export HTTP_PROXY=$http_proxy
    export https_proxy='${httpsProxySetting}'
    export HTTPS_PROXY=$https_proxy
    printf -v lan '"'"'%s,'"'"' '${kxWorkerIp}'
    printf -v pool '"'"'%s,'"'"' '${baseip}'.{1..253}
    printf -v service '"'"'%s,'"'"' '${baseip}'.{1..253}
    export no_proxy="${lan%,},${service%,},${pool%,},127.0.0.1,.'${baseDomain}'";
    export NO_PROXY=$no_proxy
    ''' | sudo tee -a /root/.bashrc /root/.zshrc /home/$vmUser/.bashrc /home/$vmUser/.zshrc
  fi
fi

# Create script to pull KX App Images from Main on second boot (after reboot in this script)
set +o histexpand
echo """
#!/bin/bash -x

. /etc/environment
export vmUser=$vmUser

echo \"Attempting to download KX Apps from KX-Main\"
sudo -H -i -u ${vmUser} bash -c 'scp -o StrictHostKeyChecking=no '${vmUser}'@'${kxMainIp}':'${KUBEDIR}'/docker-kx-*.tar '${KUBEDIR}'';

if [ -f ${KUBEDIR}/docker-kx-docs.tar ]; then
    docker load -i ${KUBEDIR}/docker-kx-docs.tar
fi

if [ -f ${KUBEDIR}/docker-kx-techradar.tar ]; then
    docker load -i ${KUBEDIR}/docker-kx-techradar.tar
fi

if [ -f ${KUBEDIR}/docker-kx-docs.tar ] && [ -f ${KUBEDIR}/docker-kx-techradar.tar ]; then
    sudo crontab -r
fi

""" | sudo tee ${KUBEDIR}/scpKxTars.sh

sudo chmod 755 ${KUBEDIR}/scpKxTars.sh
sudo crontab -l | { cat; echo "* * * * * ${KUBEDIR}/scpKxTars.sh"; } | sudo crontab -

# Set default keyboard language
keyboardLanguages=""
availableLanguages="us de gb fr it es"
for language in ${availableLanguages}
do
    if [[ -z ${keyboardLanguages} ]]; then
        keyboardLanguages="${language}"
    else
        if [[ "${language}" == "${defaultKeyboardLanguage}" ]]; then
            keyboardLanguages="${language},${keyboardLanguages}"
        else
            keyboardLanguages="${keyboardLanguages},${language}"
        fi
    fi
done

echo '''
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="'${keyboardLanguages}'"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE=\"guess\"
''' | sudo tee /etc/default/keyboard

# Reboot machine to ensure all network changes are active
if [ "${baseIpType}" == "static" ]; then
  sudo reboot
fi
