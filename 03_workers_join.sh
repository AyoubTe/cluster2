#!/bin/bash
set -e

# Run on EACH worker node
# Usage: bash 03_workers_join.sh kubeadm join 192.168.27.16:6443 --token X --discovery-token-ca-cert-hash sha256:X


# cat >> /etc/hosts <<EOF
# 192.168.27.16  cluster2-master
# 192.168.27.17  cluster2-worker1
# 192.168.27.18  cluster2-worker2
# 192.168.27.19  cluster2-worker3
# 192.168.27.20  cluster2-worker4
# EOF


sort -u /etc/hosts -o /etc/hosts

if [ -z "$*" ]; then
    echo "ERROR: Pass the full kubeadm join command as argument"
    echo "Usage: bash 03_workers_join.sh kubeadm join 192.168.27.16:6443 --token X --discovery-token-ca-cert-hash sha256:X"
    exit 1
fi

"$@" --cri-socket unix:///run/containerd/containerd.sock

echo "Worker $(hostname) joined. Now run 04_master_label_workers.sh on the master."
