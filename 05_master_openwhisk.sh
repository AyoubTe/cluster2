#!/bin/bash
set -e

export KUBECONFIG=/etc/kubernetes/admin.conf

if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# "====== Removing control-plane taint so core pods can schedule on master ======"
kubectl taint node cluster2-master node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
kubectl taint node cluster2-master node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true

# "====== Uninstalling any existing OpenWhisk release ======"
helm uninstall owdev -n openwhisk 2>/dev/null || true
kubectl delete pods -n openwhisk --all --force --grace-period=0 2>/dev/null || true
sleep 10

# "====== Deleting old PVCs (storageClassName is immutable - must recreate) ======"
kubectl delete pvc --all -n openwhisk 2>/dev/null || true
sleep 5

# "====== Creating StorageClass ======"
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# "====== Creating local directories on master ======"
mkdir -p /mnt/pv-couchdb /mnt/pv-kafka /mnt/pv-zookeeper-data /mnt/pv-zookeeper-log /mnt/pv-redis
chmod 777 /mnt/pv-couchdb /mnt/pv-kafka /mnt/pv-zookeeper-data /mnt/pv-zookeeper-log /mnt/pv-redis

# "====== Deleting old PVs if they exist ======"
kubectl delete pv pv-couchdb pv-kafka pv-zookeeper-data pv-zookeeper-log pv-redis 2>/dev/null || true
sleep 3

# "====== Creating PersistentVolumes ======"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-couchdb
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/pv-couchdb
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - cluster2-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-kafka
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/pv-kafka
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - cluster2-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-zookeeper-data
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/pv-zookeeper-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - cluster2-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-zookeeper-log
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/pv-zookeeper-log
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - cluster2-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-redis
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/pv-redis
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - cluster2-master
EOF

kubectl get pv

# "====== Installing OpenWhisk via Helm ======"
helm repo add openwhisk https://openwhisk.apache.org/charts 2>/dev/null || true
helm repo update
kubectl create namespace openwhisk 2>/dev/null || true

cat > /tmp/openwhisk-values.yaml <<EOF
whisk:
  ingress:
    type: NodePort
    apiHostName: 192.168.27.16
    apiHostPort: 31001

invoker:
  containerFactory:
    impl: "kubernetes"
  jvmHeapMB: "512"

controller:
  replicaCount: 1
  jvmHeapMB: "1024"

db:
  external: false
  wipeAndInit: true
  storageClass: local-storage
  auth:
    username: "whisk_admin"
    password: "some_passw0rd"

kafka:
  replicaCount: 1
  persistence:
    storageClass: local-storage

zookeeper:
  replicaCount: 1
  persistence:
    storageClass: local-storage

redis:
  persistence:
    storageClass: local-storage

nginx:
  httpsNodePort: 31001

affinity:
  nodeAffinity:
    invokerRequiredDuringScheduling:
      key: openwhisk-role
      value: invoker
    coreRequiredDuringScheduling:
      key: openwhisk-role
      value: core
EOF

helm install owdev openwhisk/openwhisk \
    --namespace openwhisk \
    --values /tmp/openwhisk-values.yaml \
    --timeout 20m \
    --wait

echo ""
kubectl get pv
kubectl get pvc -n openwhisk
kubectl get pods -n openwhisk -o wide
echo ""
echo "OpenWhisk API: https://192.168.27.16:31001"
echo "Auth: 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CZBkROBjVUW"
