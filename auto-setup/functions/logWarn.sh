log_info() {
    export logTimestamp=$(date '+%Y-%m-%d')
    echo "$(date '+%Y-%m-%d_%H%M%S') [WARN] ${1}" | tee -a ${installationWorkspace}/${componentName}_${logTimestamp}.${retries}.log
}
