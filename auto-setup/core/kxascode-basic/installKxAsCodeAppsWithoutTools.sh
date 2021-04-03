#!/bin/bash -eux

skelDirectory=/usr/share/kx.as.code/skel

# Build KX.AS.CODE "Docs" Image
cd /usr/share/kx.as.code/git/kx.as.code_docs
. ./build.sh

# Build KX.AS.CODE "TechRadar" Image
cd /usr/share/kx.as.code/git/kx.as.code_techradar
. ./build.sh

# Save builds as tar files
rm -f /var/tmp/docker-kx-*.tar
docker save -o ${installationWorkspace}/docker-kx-docs.tar ${dockerRegistryDomain}/kx-as-code/docs:latest
docker save -o ${installationWorkspace}/docker-kx-techradar.tar ${dockerRegistryDomain}/kx-as-code/techradar:latest
chmod 644 ${installationWorkspace}/docker-kx-*.tar

# Install KX.AS.CODE Docs Image
cd /usr/share/kx.as.code/git/kx.as.code_docs/kubernetes
. ./install.sh

# Install DevOps Tech Radar Image
cd /usr/share/kx.as.code/git/kx.as.code_techradar/kubernetes
. ./install.sh

# Return to previous directory
cd -

# Copy desktop icons to skel directory for future users
sudo cp /home/${vmUser}/Desktop/KX.AS.CODE-Docs.desktop ${skelDirectory}/Desktop
sudo cp /home/${vmUser}/Desktop/Tech-Radar.desktop ${skelDirectory}/Desktop