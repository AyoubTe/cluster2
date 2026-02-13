#!/bin/bash

# Run on ALL nodes to fully wipe Kubernetes
# Run workers FIRST, then master last

echo "Resetting $(hostname)..."

kubeadm reset -f 2>/dev/null || true
systemctl stop kubelet 2>/dev/null || true

rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/containerd
rm -rf /var/run/kubernetes /etc/cni/net.d /opt/cni
rm -rf /root/.kube

iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete cni0 2>/dev/null || true

systemctl start containerd 2>/dev/null || true

echo "Reset complete on $(hostname)"
