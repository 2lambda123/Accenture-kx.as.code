def functions
def kx_version
def kube_version

node('local') {
    dir(shared_workspace) {
        functions = load "base-vm/build/jenkins/pipelines/shared-pipeline-functions.groovy"
        println(functions)
        (kx_version, kube_version) = functions.setBuildEnvironment()
    }
}

pipeline {

    agent {
        node {
            label "local"
            customWorkspace shared_workspace
        }
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
        stage("Prepare Vagrant") {
            steps {
                script {
                    functions.addVagrantBox("vmware-desktop", kx_version)
                }
            }
        }
        stage('Execute Vagrant Action') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'DOCKERHUB_ACCOUNT', passwordVariable: 'dockerHubPassword', usernameVariable: 'dockerHubUsername')]) {
                        environmentPrefix = functions.setEnvironmentPrefix("vagrant-vmware-desktop")
                        sh """
                        if [ -z '\$(vagrant plugin list --machine-readable | grep "vagrant-vmware-desktop")' ]; then
                            vagrant plugin install vagrant-vmware-desktop
                        fi
                        export dockerHubEmail=${dockerhub_email}
                        echo \${dockerHubEmail}
                        export environmentPrefix=${environmentPrefix}
                        echo "Environment prefix will be: \${environmentPrefix}"
                        cd profiles/vagrant-vmware-desktop
                        vagrant up --provider vmware_desktop
                        """
                    }
                }
            }
        }
    }
}
