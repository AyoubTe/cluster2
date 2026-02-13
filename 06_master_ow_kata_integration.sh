#!/bin/bash
set -e

# Run ONLY on cluster2-master

export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl patch deployment owdev-invoker -n openwhisk \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/runtimeClassName","value":"kata-fc"}]' \
    2>/dev/null || true

kubectl patch daemonset owdev-invoker -n openwhisk \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/runtimeClassName","value":"kata-fc"}]' \
    2>/dev/null || true

kubectl rollout restart deployment/owdev-controller -n openwhisk 2>/dev/null || true
kubectl rollout restart deployment/owdev-invoker -n openwhisk 2>/dev/null || true

# "Waiting for rollout..."
kubectl rollout status deployment/owdev-invoker -n openwhisk --timeout=5m 2>/dev/null || true

echo ""
kubectl get pods -n openwhisk -o wide
