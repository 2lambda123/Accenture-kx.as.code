node('built-in') {
    os = sh (
        script: 'uname -s',
        returnStdout: true
    ).toLowerCase().trim()
    if ( os == "darwin" ) {
        echo "Running on Mac"
        packerOsFolder="darwin-linux"
        jqDownloadPath="${JQ_DARWIN_DOWNLOAD_URL}"
    } else if ( os == "linux" ) {
        echo "Running on Linux"
        packerOsFolder="darwin-linux"
        jqDownloadPath="${JQ_LINUX_DOWNLOAD_URL}"
    } else {
        echo "Running on Windows"
        os="windows"
        jqDownloadPath="${JQ_WINDOWS_DOWNLOAD_URL}"
        packerOsFolder="windows"
    }
}

pipeline {

    agent {
        node {
            label "built-in"
            customWorkspace shared_workspace
        }
    }

    options {
        ansiColor('xterm')
        skipDefaultCheckout()
        buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5'))
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 3, unit: 'HOURS')
    }

    tools {
        'biz.neustar.jenkins.plugins.packer.PackerInstallation' "packer-${os}"
    }

    environment {
        RED="\033[31m"
        GREEN="\033[32m"
        ORANGE="\033[33m"
        BLUE="\033[34m"
        NC="\033[0m" // No Color
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
                        if [[ ! -f ./jq* ]]; then
                            curl -L -o jq ${jqDownloadPath}
                            chmod +x ./jq
                        fi
                        export kx_version=\$(cat versions.json | ./jq -r '.kxascode')
                        export kube_version=\$(cat versions.json | ./jq -r '.kubernetes')
                        echo \${kx_version}
                        echo \${kube_version}
                        cd base-vm/build/packer/${packerOsFolder}
                        echo "${AWS_PACKER_ACCESS_KEY_ID}" | tee awsCred
                        echo "${AWS_PACKER_SECRET_ACCESS_KEY}" | tee -a awsCred
                        ${packerPath}/packer build -force -only kx.as.code-main-aws-ami \
                        -var "compute_engine_build=${aws_compute_engine_build}" \
                        -var "hostname=${kx_main_hostname}" \
                        -var "domain=${kx_domain}" \
                        -var "version=\${kx_version}" \
                        -var "kube_version=\${kube_version}" \
                        -var "vm_user=${kx_vm_user}" \
                        -var "vm_password=${kx_vm_password}" \
                        -var "instance_type=${aws_instance_type}" \
                        -var "access_key=${AWS_PACKER_ACCESS_KEY_ID}" \
                        -var "secret_key=${AWS_PACKER_SECRET_ACCESS_KEY}" \
                        -var "git_source_url=${git_source_url}" \
                        -var "git_source_branch=${git_source_branch}" \
                        -var "git_source_user=${git_source_user}" \
                        -var "git_source_token=${git_source_token}" \
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
                        ./kx-main-cloud-profiles.json
                        """
                    }}
                }
            }
        }
    }
}
