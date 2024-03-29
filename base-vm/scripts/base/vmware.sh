#!/bin/bash -x
set -euo pipefail

echo "==> Installing Open VM Tools"
# Install open-vm-tools so we can mount shared folders
sudo apt-get install -y open-vm-tools
sudo apt-get install -y open-vm-tools-desktop
# Add /mnt/hgfs so the mount works automatically with Vagrant
sudo mkdir -p /mnt/hgfs
