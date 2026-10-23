#!/usr/bin/env bash
# Create an Ubuntu 24.04 LTS desktop VM with Docker and distrobox.
#
# Ubuntu is not installed by hand. The VM boots the official cloud image, and
# cloud-init does all the setup on the first boot:
#   - creates your user (password from the prompt, SSH key from $SSH_KEY)
#   - installs ubuntu-desktop-minimal (GNOME)
#   - installs Docker CE (the daemon runs as root) and distrobox
#   - reboots into the desktop
#
# The first boot takes 10-20 minutes, because it downloads the desktop. The
# script waits for it: virt-install stops the VM at the end of the first boot
# and starts it again. Run ./load-emacs-image.sh next.
#
#   Usage:  ./create-vm.sh
#   Watch:  sudo virsh console ubuntu-emacs    (Ctrl+] to leave)
#   Open:   virt-manager, or: virt-viewer -c qemu:///system ubuntu-emacs
#   Delete: sudo virsh destroy ubuntu-emacs; \
#           sudo virsh undefine ubuntu-emacs --nvram --remove-all-storage
set -euo pipefail

VM_NAME=${VM_NAME:-ubuntu-emacs}
VM_USER=${VM_USER:-$USER}
VM_CPUS=${VM_CPUS:-8}
VM_RAM_MB=${VM_RAM_MB:-8192}
VM_DISK_GB=${VM_DISK_GB:-60}
SSH_KEY=${SSH_KEY:-$HOME/.ssh/homelab_vms.pub}

IMAGE_DIR=/var/lib/libvirt/images
BASE_URL=https://cloud-images.ubuntu.com/releases/24.04/release
BASE_IMG=ubuntu-24.04-server-cloudimg-amd64.img
DISK="$IMAGE_DIR/$VM_NAME.qcow2"

if sudo virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo "VM '$VM_NAME' already exists. Delete it first (see the header)." >&2
    exit 1
fi
if [[ ! -r $SSH_KEY ]]; then
    echo "SSH public key '$SSH_KEY' not found. Set SSH_KEY." >&2
    exit 1
fi

read -rsp "Password for '$VM_USER' in the VM: " password; echo
read -rsp "Type the password again: " password2; echo
if [[ $password != "$password2" ]]; then
    echo "The passwords are not the same." >&2
    exit 1
fi
password_hash=$(openssl passwd -6 -stdin <<<"$password")
unset password password2

# Download and verify the cloud image once. Later VMs reuse it.
if [[ ! -f $IMAGE_DIR/$BASE_IMG ]]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --progress-bar -o "$tmp/$BASE_IMG" "$BASE_URL/$BASE_IMG"
    curl -fsSL -o "$tmp/SHA256SUMS" "$BASE_URL/SHA256SUMS"
    (cd "$tmp" && grep " \*\?$BASE_IMG\$" SHA256SUMS | sha256sum -c -)
    sudo install -m 644 "$tmp/$BASE_IMG" "$IMAGE_DIR/$BASE_IMG"
    rm -rf "$tmp"
    trap - EXIT
fi

# The VM disk is a copy-on-write overlay on top of the cloud image, so the
# base image stays clean. cloud-init grows the root partition to fill it.
sudo qemu-img create -f qcow2 -F qcow2 -b "$IMAGE_DIR/$BASE_IMG" "$DISK" "${VM_DISK_GB}G"

user_data=$(mktemp)
trap 'rm -f "$user_data"' EXIT
# $RELEASE and $KEY_FILE are escaped: cloud-init fills them in, not bash.
cat >"$user_data" <<EOF
#cloud-config
hostname: $VM_NAME

groups:
  - docker

users:
  - name: $VM_USER
    groups: [sudo, docker]
    shell: /bin/bash
    lock_passwd: false
    passwd: '$password_hash'
    sudo: ALL=(ALL) ALL
    ssh_authorized_keys:
      - $(cat "$SSH_KEY")

ssh_pwauth: false

apt:
  sources:
    docker:
      source: "deb [arch=amd64 signed-by=\$KEY_FILE] https://download.docker.com/linux/ubuntu \$RELEASE stable"
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

package_update: true
package_upgrade: true
packages:
  - ubuntu-desktop-minimal
  - spice-vdagent
  - qemu-guest-agent
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - distrobox
  - zstd

# distrobox prefers podman when it finds both. Make it use Docker.
write_files:
  - path: /etc/distrobox/distrobox.conf
    content: |
      container_manager="docker"

runcmd:
  - systemctl enable --now docker qemu-guest-agent
  - systemctl set-default graphical.target

power_state:
  mode: reboot
  message: cloud-init is done, rebooting into the desktop
  condition: true
EOF

# The first boot runs with libvirt's on_reboot=destroy, so the reboot at the
# end of cloud-init stops the VM. `--wait -1' keeps virt-install running until
# then, and virt-install starts the VM again with its normal config. Without
# it, the VM stays shut off.
echo "Creating the VM. cloud-init now installs the desktop, Docker and"
echo "distrobox. This takes 10-20 minutes. Watch it in a second terminal with:"
echo "  sudo virsh console $VM_NAME"
sudo virt-install \
    --connect qemu:///system \
    --name "$VM_NAME" \
    --osinfo ubuntu24.04 \
    --vcpus "$VM_CPUS" \
    --cpu host-passthrough \
    --memory "$VM_RAM_MB" \
    --boot uefi \
    --disk "path=$DISK,format=qcow2,bus=virtio" \
    --network network=default,model=virtio \
    --graphics spice \
    --video virtio \
    --channel spicevmc \
    --import \
    --cloud-init "user-data=$user_data" \
    --noautoconsole \
    --wait -1

# Fallback: if virt-install did not start the VM again, start it here.
if [[ $(sudo virsh -c qemu:///system domstate "$VM_NAME") != running ]]; then
    sudo virsh -c qemu:///system start "$VM_NAME"
fi

echo
echo "VM '$VM_NAME' finished its first boot and started again."
echo "Run ./load-emacs-image.sh next."
