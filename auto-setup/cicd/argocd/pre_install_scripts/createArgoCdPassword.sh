#!/bin/bash

# Create Jenkins Admin Password
export generatedAdminPassword=$(managedPassword "argocd-admin-password" "${componentName}")

# Install htpasswd for bcrypt encoded password
apt-get install -y apache2-utils
export argoCdAdminPassword=$(htpasswd -nbBC 10 "" ${generatedAdminPassword} | tr -d ':\n' | sed 's/$2y/$2a/')
