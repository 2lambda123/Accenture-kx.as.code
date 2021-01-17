#!/bin/bash

export TF_VAR_ACCESS_KEY=$(cat ./config.json | jq -r '.config.ACCESS_KEY')
if [[ -z "${TF_VAR_ACCESS_KEY}" ]]; then
  echo "- [ERROR] ACCESS_KEY not defined in ./config.json"
  error="true"
fi

export TF_VAR_SECRET_KEY=$(cat ./config.json | jq -r '.config.SECRET_KEY')
if [[ -z "${TF_VAR_SECRET_KEY}" ]]; then
  echo "- [ERROR] SECRET_KEY not defined in ./config.json"
  error="true"
fi

export TF_VAR_KX_MAIN_AMI_ID=$(cat ./config.json | jq -r '.config.KX_MAIN_AMI_ID')
if [[ -z "${TF_VAR_KX_MAIN_AMI_ID}" ]]; then
  echo "- [ERROR] KX_MAIN_AMI_ID not defined in ./config.json"
  error="true"
fi

export TF_VAR_KX_WORKER_AMI_ID=$(cat ./config.json | jq -r '.config.KX_MAIN_AMI_ID')
if [[ -z "${TF_VAR_KX_WORKER_AMI_ID}" ]]; then
  echo "- [ERROR] KX_MAIN_AMI_ID not defined in ./config.json"
  error="true"
fi

export TF_VAR_REGION=$(cat ./config.json | jq -r '.config.REGION')
if [[ -z "${TF_VAR_REGION}" ]]; then
  echo "- [ERROR] REGION not defined in ./config.json"
  error="true"
fi

export TF_VAR_AVAILABILITY_ZONE=$(cat ./config.json | jq -r '.config.AVAILABILITY_ZONE')
if [[ -z "${TF_VAR_AVAILABILITY_ZONE}" ]]; then
  echo "- [ERROR] AVAILABILITY_ZONE not defined in ./config.json"
  error="true"
fi

export TF_VAR_VPC_CIDR_BLOCK=$(cat ./config.json | jq -r '.config.VPC_CIDR_BLOCK')
if [[ -z "${TF_VAR_VPC_CIDR_BLOCK}" ]]; then
  echo "- [ERROR] VPC_CIDR_BLOCK not defined in ./config.json"
  error="true"
fi

export TF_VAR_PRIVATE_ONE_SUBNET_CIDR=$(cat ./config.json | jq -r '.config.PRIVATE_ONE_SUBNET_CIDR')
if [[ -z "${TF_VAR_PRIVATE_ONE_SUBNET_CIDR}" ]]; then
  echo "- [ERROR] PRIVATE_ONE_SUBNET_CIDR not defined in ./config.json"
  error="true"
fi

export TF_VAR_PRIVATE_TWO_SUBNET_CIDR=$(cat ./config.json | jq -r '.config.PRIVATE_TWO_SUBNET_CIDR')
if [[ -z "${TF_VAR_PRIVATE_TWO_SUBNET_CIDR}" ]]; then
  echo "- [ERROR] PRIVATE_TWO_SUBNET_CIDR not defined in ./config.json"
  error="true"
fi

export TF_VAR_PUBLIC_SUBNET_CIDR=$(cat ./config.json | jq -r '.config.PUBLIC_SUBNET_CIDR')
if [[ -z "${TF_VAR_PUBLIC_SUBNET_CIDR}" ]]; then
  echo "- [ERROR] PUBLIC_SUBNET_CIDR not defined in ./config.json"
  error="true"
fi

export TF_VAR_PUBLIC_KEY=$(cat ./config.json | jq -r '.config.PUBLIC_KEY')
if [[ -z "${TF_VAR_PUBLIC_KEY}" ]]; then
  echo "- [ERROR] PUBLIC_KEY not defined in ./config.json"
  error="true"
fi

export TF_VAR_VPN_SERVER_CERT_ARN=$(cat ./config.json | jq -r '.config.VPN_SERVER_CERT_ARN')
if [[ -z "${TF_VAR_VPN_SERVER_CERT_ARN}" ]]; then
  echo "- [ERROR] ACCESVPN_SERVER_CERT_ARNS_KEY not defined in ./config.json"
  error="true"
fi

export TF_VAR_VPN_CLIENT_CERT_ARN=$(cat ./config.json | jq -r '.config.VPN_CLIENT_CERT_ARN')
if [[ -z "${TF_VAR_VPN_CLIENT_CERT_ARN}" ]]; then
  echo "- [ERROR] VPN_CLIENT_CERT_ARN not defined in ./config.json"
  error="true"
fi

export TF_VAR_KX_DOMAIN=$(cat ./config.json | jq -r '.config.KX_DOMAIN')
if [[ -z "${TF_VAR_VPN_CLIENT_CERT_ARN}" ]]; then
  echo "- [ERROR] KX_DOMAIN not defined in ./config.json"
  error="true"
fi

export TF_VAR_NUM_KX_WORKER_NODES=$(cat ./config.json | jq -r '.config.NUM_KX_WORKER_NODES')
if [[ -z "${TF_VAR_VPN_CLIENT_CERT_ARN}" ]]; then
  echo "- [ERROR] NUM_KX_WORKER_NODES not defined in ./config.json"
  error="true"
fi

if [[ "${error}" == "true" ]]; then
  echo "Above is a list of properties missing from ./config.json. Please complete missing values and try again."
  exit 1
fi