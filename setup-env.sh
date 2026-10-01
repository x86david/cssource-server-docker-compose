#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "===================================================="
echo " Starting Debian WSL & Docker Environment Setup..."
echo "===================================================="

# 1. System Update & Full Upgrade
echo "[1/6] Updating and upgrading system packages..."
sudo apt-get update && sudo apt-get full-upgrade -y

# 2. Install Prerequisites
echo "[2/6] Installing required dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw \
    htop

# 3. Clean up older conflicting Docker packages (if any)
echo "[3/6] Cleaning up any old/conflicting Docker packages..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
done

# 4. Set up Docker's Official Repository & GPG Key
echo "[4/6] Adding Docker's official GPG key and repository..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.asc
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine & Compose Plugin
echo "[5/6] Installing Docker Engine and Docker Compose..."
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 6. Configure User Permissions for Docker (Avoid using sudo for docker)
echo "[6/6] Configuring user permissions for Docker..."
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi
sudo usermod -aG docker "$USER"

echo "===================================================="
echo " Setup Complete Successfully!"
echo "===================================================="
echo "-> Current directory: $(pwd)"
echo "-> Docker version installed:"
docker --version
docker compose version
echo ""
echo "NOTE: To apply Docker group changes without restarting WSL,"
echo "run this command in your terminal now: newgrp docker"
echo "===================================================="
