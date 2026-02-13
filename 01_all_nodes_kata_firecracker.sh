#!/bin/bash
set -e

# Run on ALL nodes

KATA_VERSION="2.5.2"
FC_VERSION="1.4.1"
ARCH="x86_64"

apt-get install -y cpu-checker

if ! kvm-ok; then
    echo "ERROR: KVM not available. Enable nested virtualization on the hypervisor host."
    exit 1
fi

if ! command -v kata-runtime &>/dev/null; then
    # "Downloading Kata Containers ${KATA_VERSION}..."
    KATA_URL="https://github.com/kata-containers/kata-containers/releases/download/${KATA_VERSION}/kata-static-${KATA_VERSION}-x86_64.tar.xz"
    curl -fsSL --retry 3 "$KATA_URL" -o /tmp/kata-static.tar.xz
    tar -xf /tmp/kata-static.tar.xz -C /
    rm /tmp/kata-static.tar.xz
fi

ln -sf /opt/kata/bin/kata-runtime /usr/local/bin/kata-runtime 2>/dev/null || true
ln -sf /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-v2 2>/dev/null || true

kata-runtime --version

# "Downloading Firecracker ${FC_VERSION}..."
curl -fsSL --retry 3 \
    "https://github.com/firecracker-microvm/firecracker/releases/download/v${FC_VERSION}/firecracker-v${FC_VERSION}-${ARCH}.tgz" \
    -o /tmp/firecracker.tgz
tar -xf /tmp/firecracker.tgz -C /tmp
install -m 755 /tmp/release-v${FC_VERSION}-${ARCH}/firecracker-v${FC_VERSION}-${ARCH} /usr/local/bin/firecracker
install -m 755 /tmp/release-v${FC_VERSION}-${ARCH}/jailer-v${FC_VERSION}-${ARCH} /usr/local/bin/jailer
rm -rf /tmp/firecracker.tgz /tmp/release-v${FC_VERSION}-${ARCH}

firecracker --version

mkdir -p /etc/kata-containers

KATA_KERNEL=$(ls /opt/kata/share/kata-containers/vmlinux* 2>/dev/null | grep -v initrd | head -1)
KATA_IMAGE=$(ls /opt/kata/share/kata-containers/kata-containers*.img 2>/dev/null | head -1)
KATA_VIRTIOFSD=$(find /opt/kata -name "virtiofsd" 2>/dev/null | head -1)

echo "Kernel:    ${KATA_KERNEL}"
echo "Image:     ${KATA_IMAGE}"
echo "Virtiofsd: ${KATA_VIRTIOFSD}"

cat > /etc/kata-containers/configuration-fc.toml <<EOF
[hypervisor.firecracker]
path = "/usr/local/bin/firecracker"
jailer_path = "/usr/local/bin/jailer"
kernel = "${KATA_KERNEL}"
image = "${KATA_IMAGE}"
machine_type = ""
default_vcpus = 1
default_maxvcpus = 0
default_memory = 2048
default_maxmemory = 0
disable_block_device_use = false
shared_fs = "virtio-fs"
virtio_fs_daemon = "${KATA_VIRTIOFSD}"
virtio_fs_cache_size = 0
virtio_fs_extra_args = []
virtio_fs_cache = "auto"
block_device_driver = "virtio-mmio"
enable_iothreads = false
enable_jailer = true
jailer_cgroup = ""
sandbox_cgroup_only = false
rootless = false

[runtime]
enable_debug = false
enable_cpu_memory_hotplug = false
internetworking_model = "tcfilter"
disable_new_netns = false
sandbox_bind_mounts = []
experimental = []
EOF

CONTAINERD_CFG="/etc/containerd/config.toml"

if ! grep -q "kata-fc" "$CONTAINERD_CFG"; then
    cat >> "$CONTAINERD_CFG" <<'ENDOFBLOCK'

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc]
          runtime_type = "io.containerd.kata-fc.v2"
          privileged_without_host_devices = true
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc.options]
            ConfigPath = "/etc/kata-containers/configuration-fc.toml"
ENDOFBLOCK
fi

systemctl restart containerd
systemctl is-active containerd

echo ""
echo "Kata + Firecracker setup done on $(hostname)"
kata-runtime kata-env 2>/dev/null | grep -E "Version|Path" | head -10 || true
