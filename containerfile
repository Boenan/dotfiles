FROM ghcr.io/ublue-os/arch-toolbox:20251106

RUN pacman -Sy archlinux-keyring

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
  pacman -S --clean --clean && \
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
RUN yay -S --noconfirm \
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
    kubectx \
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
  

USER root
WORKDIR /

RUN userdel -r build && \
  rm -drf /home/build && \
  sed -i '/build ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
  sed -i '/root ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
  rm -rf /home/build/.cache/* && \
  rm -rf /tmp/* /var/cache/podman/pkg/*
  

COPY --chmod=777 . /dotfiles
