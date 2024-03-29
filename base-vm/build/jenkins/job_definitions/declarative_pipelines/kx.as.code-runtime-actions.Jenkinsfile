def functions
def kx_version
def kube_version
def virtualboxCliPath
def vmwareCliPath
def parallelsCliPath

node('built-in') {
    dir(shared_workspace) {
        functions = load "base-vm/build/jenkins/job_definitions/shared_functions/shared-pipeline-functions.groovy"
        println(functions)
        def node_type = ''
        ( kx_version, kube_version, virtualboxCliPath, vmwareCliPath, parallelsCliPath ) = functions.setBuildEnvironment( profile,node_type, vagrant_action )
    }
}

pipeline {

    agent {
        node {
            label "built-in"
            customWorkspace shared_workspace
        }
    }

    parameters {
        string(name: 'kx_main_version', defaultValue: '', description: '')
        string(name: 'kx_node_version', defaultValue: '', description: '')
        string(name: 'kx_version_override', defaultValue: '', description: '')
        string(name: 'num_kx_main_nodes', defaultValue: '', description: '')
        string(name: 'num_kx_worker_nodes', defaultValue: '', description: '')
        string(name: 'dockerhub_email', defaultValue: '', description: '')
        string(name: 'profile', defaultValue: '', description: '')
        string(name: 'profile_path', defaultValue: '', description: '')
        string(name: 'vagrant_action', defaultValue: '', description: '')
    }

    options {
        ansiColor('xterm')
        skipDefaultCheckout()
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 3, unit: 'HOURS')
    }

    stages {
        stage('Execute Vagrant Action'){
            steps {
                script {
                    dir(shared_workspace) {
                        withCredentials([file(credentialsId: 'VM_CREDENTIALS_FILE', variable: 'vmCredentialsFile')]) {
                        withCredentials([string(credentialsId: 'SECRET_TEXT', variable: 'hash')]) {
                            sh """
                            #!/bin/bash
                            set -x
                            export mainBoxVersion=${kx_main_version}
                            export nodeBoxVersion=${kx_node_version}
                            export num_kx_main_nodes=${num_kx_main_nodes}
                            export num_kx_worker_nodes=${num_kx_worker_nodes}
                            echo "Profile path: ${profile_path}"
                            echo "Vagrant action: ${vagrant_action}"
                            echo "Current directory \$(pwd)"
                            cd profiles/vagrant-${profile}
                            # Fix for Windows to correct path
                            export vmCredentialsFile=\$(echo "$vmCredentialsFile" | sed 's;\\\\;\\/;g' | sed 's;:;;g')
                            if [ "\$(echo \$vmCredentialsFile | cut -c-1)" != "/" ]; then
                                export vmCredentialsFile="/\${vmCredentialsFile}"
                            fi
                            cp -f \$vmCredentialsFile ./.vmCredentialsFile
                            vagrant global-status --prune
                            echo "Vagrant prune completed"
                            runningProfileMainVms=\$(vagrant status --no-tty | grep kx-main | grep ${profile} | grep running || true)
                            runningProfileNodeVms=\$(vagrant status --no-tty | grep kx-node | grep ${profile} | grep running || true)
                            importedKxMainBoxes=\$(vagrant box list | grep kx-main | grep ${profile} | grep \${mainBoxVersion} || true)
                            importedKxNodeBoxes=\$(vagrant box list | grep kx-node | grep ${profile} | grep \${nodeBoxVersion} || true)
                            if [ "\${runningProfileMainVms}" = "" ]; then
                                vagrant box remove kxascode/kx-main --provider ${profile} --box-version 0 --force || true
                            fi
                            if [ "\${runningProfileNodeVms}" = "" ]; then
                                vagrant box remove kxascode/kx-node --provider ${profile} --box-version 0 --force || true
                            fi
                            if [ "\${importedKxMainBoxes}" != "" ]; then
                                vagrant box remove kxascode/kx-main --provider ${profile} --box-version \${mainBoxVersion} --force || true
                            fi
                            if [ "\${importedKxNodeBoxes}" != "" ]; then
                                vagrant box remove kxascode/kx-node --provider ${profile} --box-version \${nodeBoxVersion} --force || true
                            fi
                            echo "About to execute vagrant ${vagrant_action} on ${profile}"
                            if [ "${vagrant_action}" = "destroy" ]; then
                                vagrant destroy --force --no-tty
                            elif [ "${vagrant_action}" = "up" ]; then
                                vagrant box update
                                vagrant up --no-tty
                                if [ \${num_kx_main_nodes} -gt 1 ]; then
                                    i=2
                                    while [ \$i -le \${num_kx_main_nodes} ];
                                    do
                                        vagrant up --no-tty kx-main\$i
                                        let i=\$i+1
                                    done
                                fi
                                if [ \${num_kx_worker_nodes} -gt 0 ]; then
                                    i=1
                                    while [ \$i -le \${num_kx_worker_nodes} ];
                                    do
                                        vagrant up --no-tty kx-worker\$i
                                        let i=\$i+1
                                    done
                                fi
                            else
                                vagrant ${vagrant_action} --no-tty
                            fi
                            if [ \"${profile}\" = \"virtualbox\" ]; then
                                \"${virtualboxCliPath}\" list vms
                            elif [ \"${profile}\" = \"parallels\" ]; then
                                \"${parallelsCliPath}\" list
                            elif [ \"${profile}\" = \"vmware-desktop\" ]; then
                                \"${vmwareCliPath}\" list
                            fi
                            """
                        }}
                    }
                }
            }
        }
    }
}
