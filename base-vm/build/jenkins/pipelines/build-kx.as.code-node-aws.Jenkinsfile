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

    tools {
        'biz.neustar.jenkins.plugins.packer.PackerInstallation' "packer-${os}"
    }

    stages {
        stage('Build the AMI'){
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'GIT_KX.AS.CODE_SOURCE', passwordVariable: 'git_source_token', usernameVariable: 'git_source_user')]) {
                      withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: "AWS_PACKER_ACCESS",
                        accessKeyVariable: 'AWS_PACKER_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_PACKER_SECRET_ACCESS_KEY'
                      ]]) {
                            def packerPath = tool "packer-${os}"
                            if ( "${os}" == "windows" ) {
                                packerPath = packerPath.replaceAll("\\\\","/")
                            }
                            sh """
                            cd base-vm/build/packer/${packerOsFolder}
                            ${packerPath}/packer build -force -only kx.as.code-node-aws-ami \
                            -var "compute_engine_build=${aws_compute_engine_build}" \
                            -var "hostname=${kx_node_hostname}" \
                            -var "domain=${kx_domain}" \
                            -var "version=${kx_version}" \
                            -var "kube_version=${kube_version}" \
                            -var "vm_user=${kx_vm_user}" \
                            -var "vm_password=${kx_vm_password}" \
                            -var "instance_type=${aws_instance_type}" \
                            -var "access_key=${AWS_PACKER_ACCESS_KEY_ID}" \
                            -var "secret_key=${AWS_PACKER_SECRET_ACCESS_KEY}" \
                            -var "source_ami=${aws_source_ami}" \
                            -var "ami_groups=${aws_ami_groups}" \
                            -var "vpc_region=${aws_vpc_region}" \
                            -var "availability_zone=${aws_availability_zone}" \
                            -var "vpc_id=${aws_vpc_id}" \
                            -var "vpc_subnet_id=${aws_vpc_subnet_id}" \
                            -var "associate_public_ip_address=${aws_associate_public_ip_address}" \
                            -var "ssh_interface=${aws_ssh_interface}" \
                            -var "base_image_ssh_user=${aws_ssh_username}" \
                            -var "shutdown_behavior=${aws_shutdown_behavior}" \
                            ./kx.as.code-node-cloud-profiles.json
                            """
                         }
                    }
                }
            }
        }
    }
}
