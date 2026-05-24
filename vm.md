# Ubuntu 24.04 VM & Distrobox Setup Guide

This guide outlines the steps to configure a Ubuntu 24.04 LTS virtual machine on an Arch Linux host (Ryzen AI Pro 9 HX) and set up a development environment using Distrobox.

## Phase 1: Host Configuration (Arch Linux)

### 1. Install the Virtualization Stack
```bash
sudo pacman -S qemu-full virt-manager virt-viewer libvirt dnsmasq iptables-nft ovmf swtpm gst-plugins-good gst-libav
```

### 2. Enable and Start Services
```bash
sudo systemctl enable --now libvirtd.service
```

### 3. Configure User Permissions
Add your user to the `libvirt` group to manage VMs without `sudo`.
```bash
sudo usermod -aG libvirt $(whoami)
```
**Note:** You must log out and log back in for this to take effect.

### 4. Activate Default NAT Network
Libvirt needs a virtual network for the VM to access the internet.
```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

---

## Phase 2: VM Creation (virt-manager)

Launch `virt-manager` from your terminal or application menu.

### 1. New Virtual Machine
- Click **"Create a new virtual machine"**.
- Choose **"Local install media (ISO image)"** and select your Ubuntu 24.04 Desktop ISO.

### 2. Resource Allocation (Optimized for Ryzen AI)
- **Memory:** 8192 MB (8GB) or more.
- **CPUs:** 8 cores (Your HX processor has plenty).

### 3. Hardware Customization (Before Installing)
Check the box **"Customize configuration before install"** on the last step.
- **Overview:** Ensure **Firmware** is set to `UEFI x86_64: /usr/share/ovmf/x64/OVMF_CODE.4m.fd` (or similar).
- **CPUs:** Set **Model** to `host-passthrough` for maximum performance on your Ryzen CPU.
- **Video:** Set **Model** to `Virtio` and check **3D Acceleration**.
- **Display Spice:** Ensure **Listen type** is set to `None` and **OpenGL** is checked (select your iGPU).
- **TPM:** Add a TPM device (Model: TIS, Type: Emulated) if not already present.

---

## Phase 3: Guest Setup (Inside Ubuntu VM)

Once Ubuntu is installed and you are logged in:

### 1. Install Distrobox & Podman
```bash
sudo apt update
sudo apt install -y distrobox podman
```

### 2. Clone Dotfiles
```bash
git clone https://github.com/Boenan/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. Build the Dev Container
Build the image using the provided `containerfile.ubuntu`:
```bash
podman build -f containerfile.ubuntu -t ubuntu-dev-env .
```

### 4. Create and Enter Distrobox
```bash
distrobox create --name dev-box --image ubuntu-dev-env
distrobox enter dev-box
```

---

## Phase 4: Post-Installation Tips

### Exporting Apps
If you want to use `ghostty` or `hx` from the container directly in the Ubuntu app menu:
```bash
# Inside the distrobox
distrobox-export --app ghostty
distrobox-export --bin /usr/local/bin/hx --export-path ~/.local/bin
```

### Clipboard Sharing
Ensure `spice-vdagent` is installed in the Ubuntu guest for copy-paste support between Arch and the VM:
```bash
sudo apt install spice-vdagent
```
