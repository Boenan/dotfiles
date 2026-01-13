FROM ghcr.io/ublue-os/arch-toolbox:20251106

RUN pacman -Sy archlinux-keyring --noconfirm

RUN pacman -Su --noconfirm \
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
    jq \
    yq \
    kubectl \
    istio \
    k9s \
    helm \
    helmfile \
    kustomize \
    kubeseal \
    kubectx \
    kubens \
    argocd \
    gopls \
    delve \
    gofumpt \
    yaml-language-server \
    bash-language-server \
    wget \
    unzip \
    openssh \
    glibc-locales \
    shellcheck \
    fuse-overlayfs \
    podman \
    docker \
    python-lsp-server && \
    yes | pacman -Scc

RUN wget https://github.com/int128/kubelogin/releases/download/v1.35.2/kubelogin_linux_amd64.zip && \
    unzip kubelogin_linux_amd64.zip && \
    mv kubelogin /usr/local/bin/kubelogin && \
    ln -s /usr/local/bin/kubelogin /usr/local/bin/kubectl-oidc_login && \
    rm kubelogin_linux_amd64.zip

COPY --chmod=777 . /dotfiles
