minioS3GetAccessAndSecretKeys() {

    if checkApplicationInstalled "minio-operator" "storage"; then

        username=${1}

        # Get MinIO Access Access and Secret Keys
        export minioAccessKey=$(managedApiKey "minio-s3-${username}-sa-access-key" "minio-operator")
        export minioSecretKey=$(managedApiKey "minio-s3-${username}-sa-secret-key" "minio-operator")

    fi

}
