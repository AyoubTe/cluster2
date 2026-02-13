#!/bin/bash
set -e

# "Removing bad APT sources..."

rm -f /etc/apt/sources.list.d/firecracker*.list
rm -f /etc/apt/sources.list.d/kata*.list

grep -rl "firecracker-microvm.dev" /etc/apt/ | xargs rm -f 2>/dev/null || true

# "Romve Kubernetes GPG key..."

rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list

# "Rmove Docker GPG key..."

rm -f /etc/apt/keyrings/docker.gpg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" \
    > /etc/apt/sources.list.d/docker.list

# "Running apt-get update to verify..."
apt-get update -y

echo ""
echo "Cleanup done on $(hostname). Now run 00_all_nodes_common.sh"
