# Plain Emacs 30 (config from ./emacs) in a distrobox container, fully
# self-contained.
#
# Target: an air-gapped Ubuntu 24.04 VM. Nothing here may need the network at
# RUN time, so every package, grammar, font, LSP server, native module and
# native-comp artifact is baked at BUILD time.
#
#   Build:  docker build -f containerfile.emacs -t emacs:latest .
#   Save:   docker save emacs:latest | zstd -o emacs.tar.zst
#   Load:   (on the VM) zstd -dc emacs.tar.zst | podman load
#   Create: distrobox create --image emacs:latest --name emacs
#   Enter:  distrobox enter emacs -- emacs
#   Export: distrobox enter emacs -- distrobox-export --bin /usr/local/bin/emacs
#
# Why the odd path: distrobox bind-mounts the host $HOME, so ~/.emacs.d and
# ~/.config/emacs inside the container are the HOST's files (built against the
# host's Emacs). The config, its elpa/ packages, grammars and eln-cache all
# live at /emacs.d instead, which the host home cannot shadow.

FROM quay.io/toolbx/ubuntu-toolbox:24.04

ARG IOSEVKA_VERSION=34.9.0
ARG NERD_FONTS_VERSION=3.5.1
ARG EZA_VERSION=0.23.5
ARG STARSHIP_VERSION=1.27.0
ARG ATUIN_VERSION=18.24.2
ARG ZOXIDE_VERSION=0.10.0
ARG NODE_VERSION=22.14.0
ARG TERRAFORM_VERSION=1.17.0
ARG TERRAFORM_LS_VERSION=0.39.0
ARG VAULT_VERSION=2.2.1
ARG KUBECTL_VERSION=1.37.1
ARG HELM_VERSION=4.3.1
ARG ISTIO_VERSION=1.31.3
ARG ARGOCD_VERSION=3.5.6
ARG KUBESEAL_VERSION=0.41.1
ARG GLAB_VERSION=1.124.0
ARG REALM_VERSION=0.2.1
ARG KCTX_VERSION=1.0.0
ARG YQ_VERSION=4.54.1
ARG CILIUM_CLI_VERSION=0.20.1
ARG HUBBLE_VERSION=1.20.2
ARG KUBELOGIN_VERSION=1.36.4
ARG ORAS_VERSION=1.3.5

# CHECKPOINT_DISABLE stops terraform from calling checkpoint-api.hashicorp.com
# to check for new versions.
ENV DEBIAN_FRONTEND=noninteractive \
    EMACSDIR=/emacs.d \
    CHECKPOINT_DISABLE=1 \
    LANG=C.UTF-8

# ---------------------------------------------------------------------------
# Base tooling
#
# fd-find installs the binary as `fdfind` on Debian/Ubuntu, so it gets
# symlinked to `fd`. libgccjit-13-dev is what lets Emacs native-compile at
# RUNTIME (offline-safe, it needs no network -- only gcc + libgccjit).
# shellcheck backs flymake in bash-ts-mode buffers.
#
# Network tools: the base image already has openssh-client, dig, ip, ping,
# tracepath, mtr, nc, tcpdump, telnet, ethtool and lsof. The list below adds
# the rest.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libgccjit-13-dev \
        gcc-13 \
        git \
        curl \
        wget \
        unzip \
        xz-utils \
        zstd \
        ca-certificates \
        gnupg \
        software-properties-common \
        fish \
        tmux \
        ripgrep \
        fd-find \
        fzf \
        jq \
        wl-clipboard \
        xclip \
        shellcheck \
        python3 \
        python3-venv \
        pipx \
        fontconfig \
        fonts-noto-color-emoji \
        locales \
        traceroute \
        socat \
        nmap \
        iperf3 \
        net-tools \
        whois \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Emacs 30 (pure GTK, native-comp) from the PPA
# ---------------------------------------------------------------------------
RUN add-apt-repository -y ppa:ubuntuhandbook1/emacs \
    && apt-get update \
    && apt-get install -y emacs-pgtk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Podman, for nested containers inside the distrobox. This must work when the
# VM host runs docker, so it cannot use the host engine or systemd:
#   - cgroupfs and a file events log, because there is no systemd in the box.
#   - fuse-overlayfs, because the kernel cannot mount overlay on overlay.
#   - A separate rootless storage path. $HOME is the host home, and a podman
#     on the host must not share (and break) the same image store.
# Rootless podman needs a subuid/subgid range for the user. distrobox-init
# creates the user with useradd, and useradd adds that range to /etc/subuid
# and /etc/subgid.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        podman \
        uidmap \
        fuse-overlayfs \
        slirp4netns \
    && rm -rf /var/lib/apt/lists/* \
    && printf '%s\n' \
      '[containers]' \
      'netns = "slirp4netns"' \
      '' \
      '[engine]' \
      'cgroup_manager = "cgroupfs"' \
      'events_logger = "file"' \
      > /etc/containers/containers.conf \
    && printf '%s\n' \
      '[storage]' \
      'driver = "overlay"' \
      'runroot = "/run/containers/storage"' \
      'graphroot = "/var/lib/containers/storage"' \
      'rootless_storage_path = "$HOME/.local/share/containers/storage-distrobox"' \
      '' \
      '[storage.options.overlay]' \
      'mount_program = "/usr/bin/fuse-overlayfs"' \
      > /etc/containers/storage.conf \
    && podman --version

# ---------------------------------------------------------------------------
# Iosevka -- early-init.el sets the frame font to "Iosevka-15". Ubuntu does
# not package it, so take the TTF release from GitHub.
#
# It goes under /usr/share/fonts, NOT /usr/local/share/fonts: distrobox-init
# bind-mounts the host's /usr/share/fonts over /usr/local/share/fonts, which
# would hide the font inside the distrobox.
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/share/fonts/truetype/iosevka \
    && curl -fsSL -o /tmp/iosevka.zip \
       "https://github.com/be5invis/Iosevka/releases/download/v${IOSEVKA_VERSION}/PkgTTF-Iosevka-${IOSEVKA_VERSION}.zip" \
    && unzip -q -o /tmp/iosevka.zip -d /usr/share/fonts/truetype/iosevka \
    && rm /tmp/iosevka.zip \
    && fc-cache -f \
    && fc-list | grep -q 'Iosevka'

# ---------------------------------------------------------------------------
# Symbols Nerd Font -- Iosevka has no Nerd Font icons. init.el shows the
# private use areas with "Symbols Nerd Font Mono", so the icons of eza and
# starship render in ghostel. Same /usr/share/fonts rule as Iosevka above.
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/share/fonts/truetype/nerd-fonts-symbols \
    && curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/NerdFontsSymbolsOnly.tar.xz" \
         | tar -xJ -C /usr/share/fonts/truetype/nerd-fonts-symbols \
             SymbolsNerdFont-Regular.ttf SymbolsNerdFontMono-Regular.ttf \
    && fc-cache -f \
    && fc-list | grep -q 'Symbols Nerd Font Mono'

# ---------------------------------------------------------------------------
# Shell tools for fish in ghostel. The ls function in fish/functions/ls.fish
# runs `eza --icons', and fish/config.fish starts starship, atuin and zoxide.
# Ubuntu 24.04 has old or no versions of these, so take the pinned release
# binaries.
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
         | tar -xz -C /usr/local/bin ./eza \
    && curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
         | tar -xz -C /usr/local/bin starship \
    && curl -fsSL "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-x86_64-unknown-linux-gnu.tar.gz" \
         | tar -xz -C /usr/local/bin --strip-components=1 atuin-x86_64-unknown-linux-gnu/atuin \
    && curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
         | tar -xz -C /usr/local/bin zoxide \
    && cd /usr/local/bin \
    && chown root:root eza starship atuin zoxide \
    && chmod 755 eza starship atuin zoxide \
    && eza --version \
    && starship --version \
    && atuin --version \
    && zoxide --version

# ---------------------------------------------------------------------------
# Node -- home of the YAML and Bash language servers. They match two of the
# grammars in `treesit-auto-langs'; start them with M-x eglot. The schema
# store of yaml-language-server is turned off further down, because it
# downloads JSON schemas from schemastore.org.
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -C /usr/local --strip-components=1 -xJ \
    && npm install -g --no-fund --no-audit \
         yaml-language-server \
         bash-language-server \
    && npm cache clean --force

# ---------------------------------------------------------------------------
# Terraform, terraform-ls and Vault. init.el starts eglot in terraform-mode,
# and eglot runs `terraform-ls serve'. Taken as release zips rather than
# through the HashiCorp apt repo so the versions are pinned above and no extra
# key/repo is left configured in the image.
# ---------------------------------------------------------------------------
RUN for pair in "terraform:${TERRAFORM_VERSION}" "terraform-ls:${TERRAFORM_LS_VERSION}" \
                "vault:${VAULT_VERSION}"; do \
        name="${pair%%:*}"; version="${pair##*:}"; \
        curl -fsSL -o /tmp/hc.zip \
          "https://releases.hashicorp.com/${name}/${version}/${name}_${version}_linux_amd64.zip" \
        && unzip -q -o /tmp/hc.zip -d /usr/local/bin "$name" \
        && rm /tmp/hc.zip || exit 1; \
    done \
    && chmod 755 /usr/local/bin/terraform /usr/local/bin/terraform-ls /usr/local/bin/vault

# ---------------------------------------------------------------------------
# Kubernetes, GitLab and OCI CLIs, as pinned release files (see the ARGs
# above). All of them go to /usr/local/bin. yq comes from GitHub because the
# Ubuntu `yq' package is a different tool (a Python wrapper around jq).
# kubelogin is int128/kubelogin; the kubectl-oidc_login link lets
# `kubectl oidc-login' find it.
# ---------------------------------------------------------------------------
RUN cd /tmp \
    && curl -fsSL -o /usr/local/bin/kubectl \
         "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -fsSL -o /usr/local/bin/argocd \
         "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64" \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
         | tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm \
    && curl -fsSL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istioctl-${ISTIO_VERSION}-linux-amd64.tar.gz" \
         | tar -xz -C /usr/local/bin istioctl \
    && curl -fsSL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" \
         | tar -xz -C /usr/local/bin kubeseal \
    && curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz" \
         | tar -xz -C /usr/local/bin --strip-components=1 bin/glab \
    && curl -fsSL "https://github.com/Boenan/realm/releases/download/realm-v${REALM_VERSION}/realm-linux-x86_64.tar.gz" \
         | tar -xz -C /usr/local/bin realm \
    && curl -fsSL "https://github.com/Boenan/kctx/releases/download/kctx-v${KCTX_VERSION}/kctx-linux-x86_64.tar.gz" \
         | tar -xz -C /usr/local/bin kctx \
    && curl -fsSL -o /usr/local/bin/yq \
         "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    && curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz" \
         | tar -xz -C /usr/local/bin cilium \
    && curl -fsSL "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz" \
         | tar -xz -C /usr/local/bin hubble \
    && curl -fsSL -o /tmp/kubelogin.zip \
         "https://github.com/int128/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin_linux_amd64.zip" \
    && unzip -q -o /tmp/kubelogin.zip -d /usr/local/bin kubelogin \
    && rm /tmp/kubelogin.zip \
    && ln -sf kubelogin /usr/local/bin/kubectl-oidc_login \
    && curl -fsSL "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" \
         | tar -xz -C /usr/local/bin oras \
    && cd /usr/local/bin \
    && chown root:root kubectl argocd helm istioctl kubeseal glab realm kctx \
         yq cilium hubble kubelogin oras \
    && chmod 755 kubectl argocd helm istioctl kubeseal glab realm kctx \
         yq cilium hubble kubelogin oras \
    && kubectl version --client \
    && helm version \
    && istioctl version --remote=false \
    && argocd version --client \
    && kubeseal --version \
    && glab version \
    && yq --version \
    && cilium version --client \
    && hubble version \
    && kubelogin --version \
    && oras version \
    && vault version

# ---------------------------------------------------------------------------
# Python tools. PEP 668 forbids system-wide pip, so pipx.
#   - pylsp: init.el starts eglot in python-ts-mode, and `pylsp' is the first
#     server eglot tries there.
#   - ruff: formatting and linting from the shell.
#   - ansible: `--include-deps' is required. The `ansible' distribution is the
#     collection bundle and has no commands of its own; `ansible',
#     `ansible-playbook' and `ansible-galaxy' come from its ansible-core
#     dependency. The full bundle, not bare ansible-core, so the community
#     collections are in the image and need no download.
# ---------------------------------------------------------------------------
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin
RUN pipx install python-lsp-server \
    && pipx install ruff \
    && pipx install --include-deps ansible \
    && ansible --version

# Config last -- it is what changes most often, so everything above stays
# cached when you edit init.el. Only the two init files are copied: the
# working tree in ./emacs also carries elpa/, eln-cache/ and history built
# against the HOST's Emacs, which would be both wrong and dead weight here.
COPY emacs/early-init.el emacs/init.el /emacs.d/

# ---------------------------------------------------------------------------
# Install every package init.el asks for. Loading init.el with
# `use-package-always-ensure' set installs whatever is missing, so the package
# list lives in one place only. `package-native-compile' compiles each package
# to /emacs.d/eln-cache now, rather than in a JIT storm on first start.
# ---------------------------------------------------------------------------
RUN emacs --batch --init-directory=/emacs.d \
      --eval "(progn \
        (require 'package) \
        (setq package-native-compile t) \
        (add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t) \
        (package-initialize) \
        (package-refresh-contents))" \
      -l /emacs.d/init.el

# ---------------------------------------------------------------------------
# Tree-sitter grammars. treesit-auto would offer to download them on first
# use, which the air-gapped VM cannot do. Build them here from treesit-auto's
# own recipes (they pin ABI-14 revisions where Emacs 30 needs them) into
# /emacs.d/tree-sitter, which treesit searches by default.
#
# `--batch' does not activate installed packages, so this step and the next
# call `package-initialize' before init.el. Without it, use-package cannot
# find vertico, treesit-auto and the rest.
# ---------------------------------------------------------------------------
RUN emacs --batch --init-directory=/emacs.d \
      -f package-initialize -l /emacs.d/init.el \
      --eval "(progn \
        (setq treesit-language-source-alist \
              (treesit-auto--build-treesit-source-alist)) \
        (dolist (lang treesit-auto-langs) \
          (message \"Installing grammar: %s\" lang) \
          (treesit-install-language-grammar lang)) \
        (dolist (lang treesit-auto-langs) \
          (unless (treesit-language-available-p lang) \
            (error \"Grammar not available: %s\" lang))))"

# ---------------------------------------------------------------------------
# ghostel's native module. ghostel would otherwise offer to download it the
# first time M-x ghostel runs, on the VM. Fetch the pre-built release that
# matches the installed package, then load it once to prove it works.
# ---------------------------------------------------------------------------
RUN emacs --batch --init-directory=/emacs.d \
      -f package-initialize -l /emacs.d/init.el \
      --eval "(progn \
        (require 'ghostel-module-install) \
        (unless (ghostel--download-module (ghostel--module-directory)) \
          (error \"ghostel module download failed\")) \
        (require 'ghostel) \
        (unless (featurep 'ghostel-module) \
          (error \"ghostel module did not load\")))"

# Every mutable path must be writable by the unprivileged host user that
# distrobox maps in -- their UID is unknown at build time. This covers elpa/,
# eln-cache/, custom.el, recentf, savehist, save-place and transient.
RUN chmod -R a+rwX /emacs.d

# ---------------------------------------------------------------------------
# Launcher. `emacs` here shadows /usr/bin/emacs via PATH order and pins the
# init directory, so the host's ~/.emacs.d can never be picked up.
# ---------------------------------------------------------------------------
RUN printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/emacs --init-directory="${EMACSDIR:-/emacs.d}" "$@"' \
      > /usr/local/bin/emacs \
    && chmod 755 /usr/local/bin/emacs

# ---------------------------------------------------------------------------
# $EDITOR. `emacs-editor' opens the file in the running Emacs, through the
# server that 60server.el starts below. If no Emacs runs, `-a ""' starts a
# daemon (through the launcher above, so with /emacs.d), and `-r' opens a
# frame for it. A wrapper, not the command itself, so $EDITOR has no
# arguments for git, kubectl and sudoedit to parse.
# ---------------------------------------------------------------------------
RUN printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/emacsclient -r -a "" "$@"' \
      > /usr/local/bin/emacs-editor \
    && chmod 755 /usr/local/bin/emacs-editor

# Desktop entry for `distrobox-export --app emacs'. That command exports every
# entry that mentions "emacs", so keep only the GUI one. It calls
# /usr/bin/emacs directly, which would skip /emacs.d, so point it at the
# launcher above.
RUN find /usr/share/applications -name 'emacs*.desktop' ! -name emacs.desktop -delete \
    && sed -i 's#/usr/bin/emacs#/usr/local/bin/emacs#g' /usr/share/applications/emacs.desktop \
    && grep -q '^Exec=/usr/local/bin/emacs %F$' /usr/share/applications/emacs.desktop

# Container-only Emacs settings. Debian's 00debian.el loads every file in
# /etc/emacs/site-start.d at startup, so this applies without a change to
# init.el. It turns off the schema store of yaml-language-server, which would
# otherwise download JSON schemas from schemastore.org.
RUN printf '%s\n' \
      ';;; 50offline.el -*- lexical-binding: t; -*-' \
      "(with-eval-after-load 'eglot" \
      "  (setq-default eglot-workspace-configuration" \
      "                '(:yaml (:schemaStore (:enable :json-false)))))" \
      > /etc/emacs/site-start.d/50offline.el

# Start the Emacs server in the container only, so `emacs-editor' opens files
# in the Emacs that runs. It starts after init.el, and not in batch mode, in
# a daemon, or when a server already runs.
RUN printf '%s\n' \
      ';;; 60server.el -*- lexical-binding: t; -*-' \
      "(add-hook 'after-init-hook" \
      "          (lambda ()" \
      "            (require 'server)" \
      "            (unless (or noninteractive (daemonp) (server-running-p))" \
      "              (server-start))))" \
      > /etc/emacs/site-start.d/60server.el

# Same variables for interactive shells, whether the user lands in bash or
# fish. Fish never reads /etc/profile, so it gets its own file. config.fish
# sets EDITOR itself; it uses DOTFILES_EDITOR when it is set and vim when not,
# so vim stays the editor on machines outside this container.
RUN printf '%s\n' \
      'export EMACSDIR=/emacs.d' \
      'export EDITOR=emacs-editor VISUAL=emacs-editor KUBE_EDITOR=emacs-editor' \
      > /etc/profile.d/emacs.sh \
    && mkdir -p /etc/fish/conf.d \
    && printf '%s\n' \
      'set -gx EMACSDIR /emacs.d' \
      'set -gx DOTFILES_EDITOR emacs-editor' \
      > /etc/fish/conf.d/emacs.fish

# ---------------------------------------------------------------------------
# Dotfiles for the shell tools above: fish, starship and tmux. They are baked
# into /dotfiles, because $HOME is the host's and the VM has no copy of this
# repo. `link-dotfiles' (symlink_script.emacs.sh) links them into ~/.config;
# load-emacs-image.sh runs it once. fish writes fish_variables, so the files
# must be writable by the user that distrobox maps in.
# ---------------------------------------------------------------------------
COPY fish /dotfiles/fish
COPY starship /dotfiles/starship
COPY tmux /dotfiles/tmux
COPY --chmod=755 symlink_script.emacs.sh /usr/local/bin/link-dotfiles
RUN chmod -R a+rwX /dotfiles
