#!/usr/bin/env bash
# Copy the emacs:latest image into the VM and create the distrobox.
#
# Run this after ./create-vm.sh. It waits until cloud-init in the VM is done,
# streams the image from the host's Docker into the VM's Docker over SSH, and
# creates a distrobox named "emacs" from it.
#
#   Usage:  ./load-emacs-image.sh
#   Then:   in the VM desktop, open a terminal and run: distrobox enter emacs -- emacs
set -euo pipefail

VM_NAME=${VM_NAME:-ubuntu-emacs}
VM_USER=${VM_USER:-$USER}
SSH_KEY=${SSH_KEY:-$HOME/.ssh/homelab_vms.pub}
IMAGE=${IMAGE:-emacs:latest}

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Image '$IMAGE' not found on the host. Build it first:" >&2
    echo "  docker build -f containerfile.emacs -t $IMAGE ." >&2
    exit 1
fi

# The VM is on libvirt's private NAT network and gets a new host key each
# time it is made, so do not keep its host key.
ssh_vm() {
    ssh -i "${SSH_KEY%.pub}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$VM_USER@$vm_ip" "$@"
}

echo "Waiting for the VM to get an IP address..."
vm_ip=
until [[ -n $vm_ip ]]; do
    vm_ip=$(sudo virsh -c qemu:///system -q domifaddr "$VM_NAME" \
              | awk '{print $4}' | cut -d/ -f1 | head -1)
    [[ -n $vm_ip ]] || sleep 5
done
echo "VM IP: $vm_ip"

# cloud-init reboots the VM when it is done, so SSH drops once. Wait for the
# reboot to finish and Docker to answer.
#
# `cloud-init status' cannot be used here: after the first boot, virt-install
# removes the cloud-init config disk, so on later boots cloud-init reports
# "disabled". The boot-finished file stays from the first boot.
echo "Waiting for cloud-init to finish (10-20 minutes on the first boot)..."
until ssh_vm -o ConnectTimeout=5 \
        'test -f /var/lib/cloud/instance/boot-finished && docker info >/dev/null' 2>/dev/null; do
    sleep 10
done
if ! ssh_vm 'grep -q "\"errors\": \[\]" /var/lib/cloud/data/result.json'; then
    echo "cloud-init reported errors on the first boot:" >&2
    ssh_vm 'cat /var/lib/cloud/data/result.json' >&2
    exit 1
fi
echo "cloud-init finished with no errors."

echo "Copying $IMAGE into the VM..."
docker save "$IMAGE" | zstd -T0 -3 | ssh_vm 'zstd -dc | docker load'

echo "Creating the distrobox..."
# --no-entry: distrobox would otherwise add an app called "emacs" that only
# opens a terminal in the container.
ssh_vm "distrobox create --yes --no-entry --image '$IMAGE' --name emacs"
# The first enter runs distrobox's own setup in the container. Do it now,
# while the VM still has network, and not later in the isolated environment.
ssh_vm 'distrobox enter emacs -- true'

# Put Emacs in the app list and on PATH. Both go through the launcher in the
# image, which pins the config to /emacs.d.
ssh_vm 'distrobox enter emacs -- distrobox-export --app emacs --export-label none'
ssh_vm 'distrobox enter emacs -- distrobox-export --bin /usr/local/bin/emacs --export-path ~/.local/bin'

echo
echo "Done. In the VM, start Emacs from the app list (\"Emacs (GUI)\"),"
echo "or run 'emacs' in a terminal."
