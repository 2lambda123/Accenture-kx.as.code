#!/bin/bash

partitionExists=""
localStorageDrive=""
localStorageDrive_Partition=""

# Install nvme-cli if running on host with NVMe block devices (for example on AWS with EBS)
/usr/bin/sudo lsblk -i -o kname,mountpoint,fstype,size,maj:min,name,state,rm,rota,ro,type,label,model,serial

# Use disk name if supplied in profile-config.json - override that should only be used in rare cases
export localVolumesDiskName=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.diskName')
export localKubeVolumesDiskSize=$(cat ${profileConfigJsonPath}| jq -r '.state.provisioned_disks.local_storage_disk_size')

# Get number of local volumes to pre-provision
export number1gbVolumes=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.one_gb')
export number5gbVolumes=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.five_gb')
export number10gbVolumes=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.ten_gb')
export number30gbVolumes=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.thirty_gb')
export number50gbVolumes=$(cat ${profileConfigJsonPath} | jq -r '.config.local_volumes.fifty_gb')

if [[ -z ${localKubeVolumesDiskSize} ]] || [[ "${localKubeVolumesDiskSize}" == "null" ]]; then
  # Calculate total needed disk size (should match the value the VM was provisioned with, else automatic detection of the correct disk may fail)
  export size1gbVolumes=$(roundUp "$(awk "BEGIN{printf \"%.2f\", (($number1gbVolumes * 1)) * 1.04}")")
  export size5gbVolumes=$(roundUp "$(awk "BEGIN{printf \"%.2f\", (($number5gbVolumes * 5)) * 1.02}")")
  export size10gbVolumes=$(roundUp "$(awk "BEGIN{printf \"%.2f\", (($number10gbVolumes * 10)) * 1.02}")")
  export size30gbVolumes=$(roundUp "$(awk "BEGIN{printf \"%.2f\", (($number30gbVolumes * 30)) * 1.02}")")
  export size50gbVolumes=$(roundUp "$(awk "BEGIN{printf \"%.2f\", (($number50gbVolumes * 50)) * 1.02}")")
  export localKubeVolumesDiskSize=$(( ${size1gbVolumes} + ${size5gbVolumes} + ${size10gbVolumes} + ${size30gbVolumes} + ${size50gbVolumes} + 1 ))
fi

# Install NVME CLI if needed, for example, for AWS
nvme_cli_needed=$(df -h | grep "nvme" || true)
if [[ -n ${nvme_cli_needed} ]]; then
    /usr/bin/sudo apt install -y nvme-cli lvm2
fi

# If disk name not supplied in config, try to work out which free disk to use (by checking un-partitioned disk size against requested size in profile-config.json - only relevant)
if [[ -z ${localVolumesDiskName} ]] || [[ "${localVolumesDiskName}" == "null" ]]; then
  log_info "Drive for local storage not defined in profile-config.json. Attempting to automatically detect the correct drive."
  if [[ -f /usr/share/kx.as.code/.config/localStorageDrive ]]; then
    localStorageDrive=$(cat /usr/share/kx.as.code/.config/localStorageDrive)
  else
    localStorageDrive=$(lsblk -J | jq -r '.blockdevices[] | select(.size=="'${localKubeVolumesDiskSize}'G") | .name')
    echo "${localStorageDrive}" | /usr/bin/sudo tee /usr/share/kx.as.code/.config/localStorageDrive
  fi
  partitionExists=$(lsblk -o NAME,FSTYPE,SIZE -J | jq -r '.blockdevices[] | select(.name=="'${localStorageDrive}'") | .children[]? | select(.name=="'${localStorageDrive}'1") | .name')
else
  log_info "Setting drive for local storage volumes to ${localVolumesDiskName} as per profile-config.json"
  echo "${localVolumesDiskName}" | /usr/bin/sudo tee /usr/share/kx.as.code/.config/localStorageDrive
  localStorageDrive=${localVolumesDiskName}
fi

# Check logical partitions
/usr/bin/sudo lvs
/usr/bin/sudo df -hT
/usr/bin/sudo lsblk

# Create full partition on /dev/${localStorageDrive}
if [[ "${partitionExists}" != "${localStorageDrive}1" ]]; then
  if [[ -z $(lsblk -o NAME,FSTYPE,SIZE -J /dev/${localStorageDrive} | jq '.blockdevices[].children[]?') ]]; then
    echo 'type=83' | /usr/bin/sudo sfdisk /dev/${localStorageDrive}
    for i in {1..5}; do
      localStorageDrive_Partition=$(lsblk -o NAME,FSTYPE,SIZE -J | jq -r '.[] | .[]  | select(.name=="'${localStorageDrive}'") | .children[]?.name')
      if [[ -n ${localStorageDrive_Partition} ]]; then
        log_info "Disk ${localStorageDrive} partitioned successfully -> ${localStorageDrive_Partition}"
        break
      else
        log_warn "Disk partition could not be found on ${localStorageDrive} (attempt ${i}), trying again"
        sleep 5
      fi
    done
  fi
else
  localStorageDrive_Partition=$(lsblk -o NAME,FSTYPE,SIZE -J | jq -r '.[] | .[]  | select(.name=="'${localStorageDrive}'") | .children[]?.name')
fi

# Create physical volume if it does not exist
pv=$(pvdisplay /dev/${localStorageDrive_Partition} || true)
if [[ -z ${pv} ]]; then
  log_info "PV /dev/${localStorageDrive_Partition} did not exist, creating it."
  /usr/bin/sudo pvcreate -f /dev/${localStorageDrive_Partition} && pvdisplay
  pv=$(pvdisplay /dev/${localStorageDrive_Partition} || true)
  if [[ -z ${pv} ]]; then
    log_error "PV /dev/${localStorageDrive_Partition} still does not exist after attempting to create it. Exiting script with RC=1"
    exit 1
  else
    log_info "PV /dev/${localStorageDrive_Partition} created successfully. Continuing to provision volume group"
  fi
fi

# Create volume group if it does not exist
vg=$(vgdisplay k8s_local_vol_group || true)
if [[ -z ${vg} ]]; then
  log_info "VG k8s_local_vol_group did not exist, creating it."
  /usr/bin/sudo vgcreate k8s_local_vol_group /dev/${localStorageDrive_Partition} && vgdisplay
  vg=$(vgdisplay k8s_local_vol_group || true)
  if [[ -z ${vg} ]]; then
    log_error "VG k8s_local_vol_group still does not exist after attempting to create it. Exiting script with RC=1"
    exit 1
  else
    log_info "VG k8s_local_vol_group created successfully. Continuing to provision local volumes"
  fi
fi

# Check if nominated drive now has the necessary partition to proceed to the next step
if [[ -z $(lsblk -o NAME,FSTYPE,SIZE -J /dev/${localStorageDrive} | jq '.blockdevices[].children[]?') ]]; then
  log_error "Selected disk ${localStorageDrive} still has no partitions. Exiting script and setting local_volumes provision script to status failed. "
  exit 1
fi

BASE_K8S_LOCAL_VOLUMES_DIR=/mnt/k8s_local_volumes

create_volumes() {
    if [[ ${2} -ne 0 ]]; then
        for i in $(eval echo "{1..$2}"); do
            if [[ -z $(lsblk -J | jq -r ' .. .name? // empty | select(test("k8s_local_vol_group-k8s_'${1}'_local_k8s_volume_'${i}'"))' || true) ]]; then
                for j in {1..5}; do
                  # Added loop, as sometimes two tries are required
                  volumeSizeToCreate=${1}
                  /usr/bin/sudo lvcreate -L $(awk "BEGIN{printf \"%.2f\", (${volumeSizeToCreate} * 1024)}")M -n k8s_${1}_local_k8s_volume_${i} k8s_local_vol_group
                  /usr/bin/sudo mkfs.xfs /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i}
                  /usr/bin/sudo mkdir -p ${BASE_K8S_LOCAL_VOLUMES_DIR}/k8s_${1}_local_k8s_volume_${i}
                  errorOutput=$(/usr/bin/sudo mount /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} ${BASE_K8S_LOCAL_VOLUMES_DIR}/k8s_${1}_local_k8s_volume_${i} 2>&1 >/dev/null || true)
                  if [[ -z "${errorOutput}" ]]; then
                    log_info "Successfully mounted /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} to ${BASE_K8S_LOCAL_VOLUMES_DIR}/k8s_${1}_local_k8s_volume_${i}"
                    break
                  else
                    log_error "Mount error after mount attempt ${j}!: ${errorOutput}"
                  fi
                done
                # Don't add entry to /etc/fstab if the volumes was not created, possibly due to running out of diskspace
                if [[ -L /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} ]] && [[ -e /dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} ]]; then
                    entryAlreadyExists=$(cat /etc/fstab | grep "/dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i}" || true)
                    # Don't add entry to /etc/fstab if it already exists
                    if [[ -z ${entryAlreadyExists} ]]; then
                        /usr/bin/sudo echo '/dev/k8s_local_vol_group/k8s_'${1}'_local_k8s_volume_'${i}' '${BASE_K8S_LOCAL_VOLUMES_DIR}'/k8s_'${1}'_local_k8s_volume_'${i}' xfs defaults 0 0' | /usr/bin/sudo tee -a /etc/fstab
                    fi
                else
                    echo "/dev/k8s_local_vol_group/k8s_${1}_local_k8s_volume_${i} does not exist. Not adding to /etc/fstab. Possible reason is that there was not enough space left on the drive to create it"
                fi
            fi
        done
    fi
}

# Adding space lost when creating Sig PV
create_volumes $(awk "BEGIN{printf \"%.2f\", (1 * 1.04)}") ${number1gbVolumes}
create_volumes $(awk "BEGIN{printf \"%.2f\", (5 * 1.02)}") ${number5gbVolumes}
create_volumes $(awk "BEGIN{printf \"%.2f\", (10 * 1.02)}") ${number10gbVolumes}
create_volumes $(awk "BEGIN{printf \"%.2f\", (30 * 1.02)}") ${number30gbVolumes}
create_volumes $(awk "BEGIN{printf \"%.2f\", (50 * 1.02)}") ${number50gbVolumes}

# Check logical partitions
/usr/bin/sudo lvs
/usr/bin/sudo df -hT
/usr/bin/sudo lsblk

# Checkout Storage Provisioner
if [[ -d ./sig-storage-local-static-provisioner ]]; then
    rm -rf ./sig-storage-local-static-provisioner
fi
git clone --depth=1 https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner.git
cd sig-storage-local-static-provisioner

# Replace placeholders with environment variables from metadata.json
echo "PATH: $PATH"
envhandlebars < ${installComponentDirectory}/values.yaml > ${installationWorkspace}/${componentName}_values.yaml

# Generate install YAML file via Helm
helm template -f ${installationWorkspace}/${componentName}_values.yaml local-volume-provisioner --namespace ${namespace} ./helm/provisioner > ${installationWorkspace}/local-volume-provisioner.generated.yaml

# Apply YAML file
kubectl apply -f ${installationWorkspace}/local-volume-provisioner.generated.yaml

# Provision Storage Class
echo '''
# Only create this for K8s 1.9+
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
# Supported policies: Delete, Retain
reclaimPolicy: Delete
''' | kubectl apply -f -

# Remove "default" tag on K3s "local-path" storage class, as this will be set to "local-storage" later
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Make local storage class default
kubectl patch storageclass local-storage-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
