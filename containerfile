FROM ghcr.io/ublue-os/arch-toolbox:20251106

RUN pacman -Sy archlinux-keyring --noconfirm

RUN pacman -Su --noconfirm \
    libva-mesa-driver \
    intel-media-driver \
    vulkan-mesa-layers \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    xdg-user-dirs \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-nerd-fonts-symbols-common \
    glibc-locales \
    openssh \
    podman \
    systemd \
    shellcheck \
    fuse-overlayfs && \
  yes | pacman -Scc && \
  rm -rf /var/cache/podman/pkg/*


RUN wget -O yay.tar.gz https://github.com/Jguer/yay/releases/download/v12.5.7/yay_12.5.7_x86_64.tar.gz
RUN tar -xvf yay.tar.gz
RUN mv yay_12.5.7_x86_64/yay /usr/local/bin && rm yay.tar.gz && rm -rf yay_12.5.7_x86_64

RUN useradd -m --shell=/bin/bash build && \
  usermod -L build && \
  echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
  echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER build


WORKDIR /home/build
RUN yay -S --noconfirm --noanswerclean --noanswerdiff --noansweredit --noanswerupgrade \
    git \
    ghostty \
    fish \
    atuin \
    starship \
    tmux \
    helix \
    bat \
    eza \
    zoxide \
    ripgrep \
    fzf \
    jujutsu \
    jq \
    yq \
    kubectl \
    istio \
    k9s \
    helm \
    helmfile \
    kustomize \
    argocd \
    gopls \
    delve \
    gofumpt \
    yaml-language-server \
    ttf-font-nerd \
    bash-language-server \
    python-lsp-server \
    kubelogin \
    kubeseal

# Solve
# CVE-2024-24790
# CVE-2025-58183
RUN go install github.com/ahmetb/kubectx/cmd/kubectx@v0.9.5 && \
  go install github.com/ahmetb/kubectx/cmd/kubens@v0.9.5 && \
  go install github.com/1player/host-spawn@v1.6.2 

USER root
WORKDIR /

RUN rm /usr/sbin/host-spawn

RUN mv /home/build/go/bin/kubectx /usr/local/bin/ && \
    mv /home/build/go/bin/kubens /usr/local/bin/ && \
    mv /home/build/go/bin/host-spawn /usr/local/bin/ && \
    chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens /usr/local/bin/host-spawn

RUN userdel -r build && \
  rm -drf /home/build && \
  sed -i '/build ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
  sed -i '/root ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
  rm -rf /home/build/.cache/* && \
  rm -rf /tmp/* /var/cache/podman/pkg/*
  

COPY --chmod=777 . /dotfiles
