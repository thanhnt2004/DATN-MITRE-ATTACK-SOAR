#!/usr/bin/env bash
set -euo pipefail

SWAPFILE="/swapfile"
SWAPSIZE="4G"
SYSCTL_FILE="/etc/sysctl.d/99-datn.conf"
DOCKER_DAEMON_FILE="/etc/docker/daemon.json"

echo "[1/6] Installing base packages..."
sudo apt update
sudo apt install -y curl wget git jq htop unzip ca-certificates gnupg

echo "[2/6] Ensuring 4 GiB swap..."
if ! swapon --show=NAME | grep -qx "${SWAPFILE}"; then
  if [ ! -f "${SWAPFILE}" ]; then
    sudo fallocate -l "${SWAPSIZE}" "${SWAPFILE}"
    sudo chmod 600 "${SWAPFILE}"
    sudo mkswap "${SWAPFILE}"
  fi
  sudo swapon "${SWAPFILE}"
fi

if ! grep -qE '^/swapfile\s' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "[3/6] Applying kernel settings for ELK..."
sudo tee "${SYSCTL_FILE}" >/dev/null <<'EOF'
vm.swappiness=10
vm.max_map_count=1048576
EOF
sudo sysctl --system >/dev/null

echo "[4/6] Installing Docker Engine..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

echo "[5/6] Applying Docker daemon baseline..."
sudo mkdir -p /etc/docker
sudo tee "${DOCKER_DAEMON_FILE}" >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
sudo systemctl restart docker

TARGET_USER="${SUDO_USER:-$USER}"
if id "${TARGET_USER}" >/dev/null 2>&1; then
  sudo usermod -aG docker "${TARGET_USER}"
fi

echo "[6/6] Verification..."
free -h
swapon --show
sysctl vm.swappiness
sysctl vm.max_map_count
sudo docker --version
sudo docker compose version

echo
echo "Host baseline completed."
echo "Log out and log back in before using Docker without sudo."
