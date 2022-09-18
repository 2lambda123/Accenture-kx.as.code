#!/bin/bash

# Get global base variables from globalVariables.json
source /usr/share/kx.as.code/git/kx.as.code/auto-setup/functions/getGlobalVariables.sh # source function
getGlobalVariables

# Load Central Functions
functionsLocation="${autoSetupHome}/functions"
for function in $(find ${functionsLocation} -name "*.sh")
do
  functionName="$(cat ${function} | grep -E '^[[:alnum:]].*().*{' | sed 's/()*.{//g')"
  source ${function}
  echo "Loaded function ${functionName}()"
done

# Load CUSTOM Central Functions - these can either be new ones, or copied and edited functions from the main functions directory above, which will override the ones loaded in the previous step
getCustomVariables # load global custom variables
customFunctionsLocation="${autoSetupHome}/functions-custom"
loadedFunctions="$(compgen -A function)"
for function in $(find ${customFunctionsLocation} -name "*.sh")
do
  source ${function}
  customFunctionName="$(cat ${function} | grep -E '^[[:alnum:]].*().*{' | sed 's/()*.{//g')"
  if [[ -z $(echo "${loadedFunctions}" | grep ${customFunctionName}) ]]; then
    log_debug "Loaded new custom function ${customFunctionName}()"
  else
    log_debug "Overriding central function ${customFunctionName}() with custom one!"
  fi
done

# Establish whether running on AMD64 or ARM64 CPU architecture
getCpuArchitecture

# Declare variables to avoid ubound errors
export retries="0"
export action=""
export componentName=""
export componentInstallationFolder=""
export payload=""
export dockerHubUsername=""
export dockerHubPassword=""
export dockerHubEmail=""
export forceStorageClassToLocal="false"
export kcPod=""

# Get and export versions - currently versions for Kubernetes and KX.AS.CODE
getVersions

# Install envhandlebars needed to do moustache variable replacements
installEnvhandlebars

# Import error handler
#source "${sharedGitHome}/kx.as.code/base-vm/dependencies/shell-core/base/trap.bash"

# Check profile-config.json file is present before starting script
waitForFile ${installationWorkspace}/profile-config.json

export logFilename=$(setLogFilename "poller")

cd ${installationWorkspace}

# Copy metadata.json to installation workspace if it doesn't exist
if [[ ! -f ${installationWorkspace}/metadata.json ]]; then
    cp ${autoSetupHome}/metadata.json ${installationWorkspace}
fi

# Wait for last provisioning shell action to complete before proceeding to next steps
# such as changing network settings and merging action files
waitForFile ${installationWorkspace}/gogogo

# Get network configuration - specifically which NIC to use or exclude
getNetworkConfiguration

# Source profile-config.json set for this KX.AS.CODE installation
getProfileConfiguration

# Get latest source code if flag set accordingly in profile-config.json
updateKxSourceOnFirstStart

# Apply customizations on first boot
if [[ ! -f /usr/share/kx.as.code/.config/network_status ]]; then
    applyCustomizations
fi

# Create and clean the external access directory
createExternalAccessDirectory

# Modify username and password if modified in profile-config.json
if [[ ! -f /usr/share/kx.as.code/.config/network_status ]]; then
  checkAndUpdateBaseUsername
  checkAndUpdateBasePassword
fi

# Switch off GUI if switch set to do so in KX.AS.CODE profile-config.json
disableLinuxDesktop

# Configure network, as well as Bind9 and HTTP(S) Proxy settings
configureNetwork

# Configure Keyboard language and layout settings
configureKeyboardSettings

# Wait for RabbitMQ web service to be reachable before continuing
timeout -s TERM 600 bash -c 'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' http://127.0.0.1:15672/cli/rabbitmqadmin)" != "200" ]]; do \
            echo "Waiting for http://127.0.0.1:15672/cli/rabbitmqadmin"; sleep 5; done'

# Check if rabbitmqadmin is installed
checkRabbitMq

# Create RabbitMQ Exchange if it does not exist
createRabbitMQExchange

# Create RabbitMQ Queues if they do not exist
createRabbitMQQueues

# Create RabbitMQ Bindings if they do not exist
createRabbitMQWorkflowBindings

# Initial actionQueues population
populateActionQueuesJson
populateActionQueuesRabbitMq

# Set tries to 0. If an install failed and the retry flag is set to true for that component in metadata.json, attempts will be made to retry up to 3 times
retries=0
logRc=0
rc=0

# Get total number of messages
sleep 5

# In case of reboot or restart of this poller, move item from wip_queue to retry queue, or failure queue, if retries >= 3
wipQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="wip_queue") | .messages')
if [[ ${wipQueue} -ne 0 ]]; then
  payload=$(rabbitmqadmin get queue=wip_queue --format=raw_json ackmode=ack_requeue_false | jq -c -r '.[].payload')
  componentName=$(echo ${payload} | jq -c -r '.name')
  log_debug "Loaded payload from wip_queue after restart: ${payload}"
  retries=$(echo ${payload} | jq -c -r '.retries')
  if [[ ${retries} -ge 3 ]]; then
    rabbitmqadmin publish exchange=action_workflow routing_key=failed_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
    waitForMessageOnActionQueue "failed_queue" "${componentName}"
    log_debug "Published payload from wip_queue to failed_queue after restart: ${payload}"
  else
    rabbitmqadmin publish exchange=action_workflow routing_key=retry_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
    waitForMessageOnActionQueue "retry_queue" "${componentName}"
    log_debug "Published payload from wip_queue to retry_queue after restart: ${payload}"
  fi
fi

# Poll pending queue and trigger actions if message is present
while :; do

    export logFilename=$(setLogFilename "poller")

    # Check if any actionQueue templates have been added and need processing
    if [[ -n $(ls ${installationWorkspace}/aq*.json 2>/dev/null || true) ]]; then
        populateActionQueuesJson
        populateActionQueuesRabbitMq
    fi

    # Get first and last elements from Core install Queue
    lastCoreElementToInstall=$(cat ${installationWorkspace}/actionQueues.json | jq -r 'last(.action_queues.install[] | select(.install_folder=="core")) | .name')
    if [[ "${lastCoreElementToInstall}" == "null" ]]; then
        lastCoreElementToInstall=$(cat ${installationWorkspace}/actionQueues.json | jq -r 'last(.state.processed[] | select(.install_folder=="core")) | .name')
    fi
    firstCoreElementToInstall=$(cat ${installationWorkspace}/actionQueues.json | jq -r 'first(.action_queues.install[] | select(.install_folder=="core")) | .name')
    if [[ "${lastCoreElementToInstall}" == "null" ]]; then
        firstCoreElementToInstall=$(cat ${installationWorkspace}/actionQueues.json | jq -r 'first(.state.processed[] | select(.install_folder=="core")) | .name')
    fi
    count=0

    # Ensure DNS is working before continuing to avoid downstream failures
    rc=""
    while [[ ${rc} -ne 0 ]]; do
        rc=0
        host -t A deb.debian.org >/dev/null || rc=$?
        if [[ $rc -ne 0 ]]; then
          log_warn "DNS resolution currently not working. Waiting for DNS resolution to work again before continuing"
          sleep 15
        fi
    done

    completedQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="completed_queue") | .messages')
    wipQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="wip_queue") | .messages')
    failedQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="failed_queue") | .messages')
    retryQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="retry_queue") | .messages')
    pendingQueue=$(rabbitmqadmin list queues name messages --format raw_json | jq -r '.[] | select(.name=="pending_queue") | .messages')
    totalMessages=$(( ${pendingQueue} + ${completedQueue} + ${wipQueue} + ${failedQueue} + ${retryQueue} ))

    if [[ ${failedQueue} -eq 0 ]]; then

        if [[ ${wipQueue} -ne 0 ]]; then

            # Read payload from WIP queue, rather than relying on already set variables
            payload=$(rabbitmqadmin get queue=wip_queue --format=raw_json ackmode=ack_requeue_false | jq -c -r '.[].payload')
            log_debug "Read payload from wip_queue: ${payload}"
            export retries=$(echo ${payload} | jq -c -r '.retries')
            export action=$(echo ${payload} | jq -c -r '.action')
            export componentName=$(echo ${payload} | jq -c -r '.name')
            export componentInstallationFolder=$(echo ${payload} | jq -c -r '.install_folder')
            export retriesParameter=$(cat ${autoSetupHome}/${componentInstallationFolder}/${componentName}/metadata.json | jq -r '.retry?')

            # Move item from wip to completed or error queue
            if [[ ! -f ${installationWorkspace}/current_payload.err ]] && [[ -n ${payload} ]]; then
                rabbitmqadmin publish exchange=action_workflow routing_key=completed_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
                waitForMessageOnActionQueue "completed_queue" "${componentName}"
                log_debug "Moved component payload from wip_queue to completed_queue: ${payload}"
                message="${componentName} installed successfully [$((${completedQueue} + 1))/${totalMessages}]"
                notifyAllChannels "${message}" "info" "success" "${action}"
                if [[ "${componentName}" == "${lastCoreElementToInstall}" ]]; then
                    message="CONGRATULATIONS. That concludes the core setup. Your optional components will now be installed"
                    notifyAllChannels "${message}" "info" "all_core_completed_successfully" "${action}"
                    log_debug "All core component have been installed successfully"
                fi
                retries=0
            elif [[ -n ${payload} ]]; then
                if [[ "${retriesParameter}" != "false" ]] && [[ ${retries} -lt 3 ]]; then
                    sleep 10
                    ((retries = ${retries} + 1))
                    payload=$(echo ${payload} | jq --arg retries ${retries} -c -r '.retries=$retries')
                    log_debug "Moved component payload from wip_queue to retry_queue: ${payload}"
                    rabbitmqadmin publish exchange=action_workflow routing_key=retry_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
                    waitForMessageOnActionQueue "retry_queue" "${componentName}"
                    cat ${installationWorkspace}/actionQueues.json | jq -c -r '(.state.processed[] | select(.name=="'${componentName}'").retries) = "'${retries}'"' | tee ${installationWorkspace}/actionQueues.json.tmp
                    mv ${installationWorkspace}/actionQueues.json.tmp ${installationWorkspace}/actionQueues.json
                    message="${componentName} installation error after ${retries} retries. Will retry three times maximum. [$((${completedQueue} + 1))/${totalMessages}]"
                    notifyAllChannels "${message}" "warn" "failed" "${action}"
                    rm -f ${installationWorkspace}/current_payload.err
                elif [[ "${retriesParameter}" == "skip" ]] && [[ ${retries} -lt 3 ]]; then
                    payload=$(echo ${payload} | jq -c -r '(.retries)="0"' | jq -c -r '. += {"failed_retries":"'${retries}'"}')
                    rabbitmqadmin publish exchange=action_workflow routing_key=skipped_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
                    waitForMessageOnActionQueue "skipped_queue" "${componentName}"
                    log_debug "Moved component payload to skipped_queue: ${payload}"
                    message="${componentName} installation failed after ${retries} retries. Moved item to skipped queue and continuing. [$((${completedQueue} + 1))/${totalMessages}]"
                    notifyAllChannels "${message}" "error" "failed" "${action}"
                    export retries=0
                    rm -f ${installationWorkspace}/current_payload.err
                else
                    payload=$(echo ${payload} | jq -c -r '(.retries)="0"' | jq -c -r '. += {"failed_retries":"'${retries}'"}')
                    rabbitmqadmin publish exchange=action_workflow routing_key=failed_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
                    waitForMessageOnActionQueue "failed_queue" "${componentName}"
                    log_debug "Moved component payload to failed_queue: ${payload}"
                    message="${componentName} installation failed after ${retries} retries. [$((${completedQueue} + 1))/${totalMessages}]"
                    notifyAllChannels "${message}" "error" "failed" "${action}"
                    export retries=0
                    rm -f ${installationWorkspace}/current_payload.err
                fi
            fi
        fi

        # If there is something in the wip or failed queue, do not schedule an installation
        if [[ ${wipQueue} -eq 0 ]] && [[ ${failedQueue} -eq 0 ]]; then
            # Populate the payload
            if [[ ${retryQueue} -ne 0 ]]; then
                # If no errors or wip, check first if there are any installation items that need to be retried, after a failure was fixed
                log_debug "Found item in retry queue. Proceeding to get payload from retry_queue: ${payload}"
                payload=$(rabbitmqadmin get queue=retry_queue --format=raw_json ackmode=ack_requeue_false | jq -c -r '.[].payload')
            elif [[ ${pendingQueue} -ne 0 ]]; then
                # If there were no retry items, check if there is anything in the pending queue that needs to be installed
                payload=$(rabbitmqadmin get queue=pending_queue --format=raw_json ackmode=ack_requeue_false | jq -c -r '.[].payload')
                log_debug "No items found in retry queue. Proceeding to get payload from pending_queue: ${payload}"
            else
                # Nothing to process
                log_debug "Found no messages in pending or retry queues. Nothing to do."
                payload=""
            fi
            # Start the installation process if an item was found in the pending or retry queue
            if [ -n "${payload}" ]; then
                log_debug "Found payload to process: ${payload}"
                # Define Variables for autoSetup.sh script
                export action=$(echo ${payload} | jq -r '.action')
                export componentName=$(echo ${payload} | jq -r '.name')
                export componentInstallationFolder=$(echo ${payload} | jq -r '.install_folder')

                # Define component install directory
                export installComponentDirectory=${autoSetupHome}/${componentInstallationFolder}/${componentName}

                # Define location of metadata JSON file for component
                export componentMetadataJson=${installComponentDirectory}/metadata.json

                # Get retry parameter for component
                export retryParameter=$(cat ${componentMetadataJson} | jq -r '.retry?')

                # Add item to wip queue to notify install is in progress
                rabbitmqadmin publish exchange=action_workflow routing_key=wip_queue properties="{\"delivery_mode\": 2}" payload=''${payload}''
                waitForMessageOnActionQueue "wip_queue" "${componentName}"
                if [[ ${retries} -eq 0 ]]; then
                    log_debug "Notifiying installation started for ${componentName}, as not a retry - retries: ${retries}"
                    message="${componentName} installation started [$((${completedQueue} + 1))/${totalMessages}]"
                    notifyAllChannels "${message}" "info" "started" "${action}"
                fi

                # Launch autoSetup.sh
                if [[ "${componentName}" == "${firstCoreElementToInstall}" ]]; then
                    notify "Initialization started. Please be patient. This could take up to 30 minutes, depending on your system size and speed of internet connection" "dialog-warning"
                    echo "${componentName} = ${firstCoreElementToInstall}"
                fi
                count=$((count + 1))
                export error=""

                # Check if the Docker Hub Download Rate Limit is being reached which may lead to error and notify the user appropriately
                # User Dockerhub account if it exists
                checkDockerHubRateLimit

                # Launch the component installation process
                rc=0
                log_debug "Launching installation process for \"${componentName}\": ${payload}"
                log_debug "${autoSetupHome}/autoSetup.sh ''${payload}''"
                ${autoSetupHome}/autoSetup.sh ''${payload}'' 2>> ${logFilename} || rc=$? && log_debug "Installation of \"${componentName}\" returned with rc=$rc"
                if [[ ${rc} -ne 0 ]]; then
                  log_error "Installation of returned with a non zero return code ($rc)"
                  echo ${payload} | sudo tee ${installationWorkspace}/current_payload.err
                fi
                export logFilename=$(setLogFilename "poller")
                if [[ "$(echo ${payload} | jq '.action')" == "install" ]]; then
                    log_debug "Install process for \"${componentName}\" returned with \$?=${logRc} and rc=$rc"
                elif [[ "$(echo ${payload} | jq '.action')" == "executeTask" ]]; then
                    log_debug "Task execution process for \"${componentName}\" returned with \$?=${logRc} and rc=$rc"
                fi
            fi
            sleep 5
        fi
        sleep 5
    fi
    sleep 5
done
