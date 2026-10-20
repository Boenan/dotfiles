# Doom Emacs (v3/master) in a distrobox container, fully self-contained.
#
# Target: an air-gapped Ubuntu 24.04 VM. Nothing here may need the network at
# RUN time, so every package, grammar, font, LSP server and native-comp
# artifact is baked at BUILD time.
#
#   Build:  docker build -f containerfile.emacs -t doom-emacs:latest .
#   Save:   docker save doom-emacs:latest | zstd -o doom-emacs.tar.zst
#   Load:   (on the VM) zstd -dc doom-emacs.tar.zst | podman load
#   Create: distrobox create --image doom-emacs:latest --name emacs
#   Enter:  distrobox enter emacs -- emacs
#   Export: distrobox enter emacs -- distrobox-export --bin /usr/local/bin/emacs
#
# Why the odd paths: distrobox bind-mounts the host $HOME, so ~/.emacs.d and
# ~/.config/doom inside the container are the HOST's files (built against the
# host's Emacs). Doom therefore lives at /emacs.d, the private config at /doom,
# and all mutable state at /doom-local -- none of which the host home can shadow.

FROM quay.io/toolbx/ubuntu-toolbox:24.04

# Pinned to the commits currently checked out in ./emacs.d. Bump deliberately;
# the framework and its module tree must move together.
ARG DOOM_REF=46687e54e
ARG NERD_FONTS_VERSION=v3.4.0
ARG NODE_VERSION=22.14.0
ARG TERRAFORM_VERSION=1.16.4
ARG TERRAFORM_LS_VERSION=0.39.0
# Ahead-of-time native compilation: much longer build and a bigger image, but
# no first-run JIT compilation storm. Set to --aot to enable.
ARG DOOM_AOT=
# C#/.NET is off by default: config.el disables both omnisharp and csharp-roslyn,
# so the 1.5GB SDK would sit unused. Set to 1 to include it.
ARG WITH_DOTNET=0

ENV DEBIAN_FRONTEND=noninteractive \
    EMACSDIR=/emacs.d \
    DOOMDIR=/doom \
    DOOMLOCALDIR=/doom-local/ \
    LANG=C.UTF-8

# ---------------------------------------------------------------------------
# Base tooling
#
# fd-find installs the binary as `fdfind` on Debian/Ubuntu; Doom looks for `fd`,
# so it gets symlinked below. libgccjit-13-dev is what lets Emacs native-compile
# at RUNTIME (offline-safe, it needs no network -- only gcc + libgccjit).
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libtool-bin \
        libvterm-dev \
        libgccjit-13-dev \
        gcc-13 \
        git \
        curl \
        wget \
        unzip \
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
        sqlite3 \
        shellcheck \
        aspell \
        aspell-en \
        pandoc \
        editorconfig \
        python3 \
        python3-venv \
        pipx \
        fontconfig \
        fonts-noto-color-emoji \
        locales \
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
# Nerd Fonts -- config.el asks for "Hack Nerd Font"; the symbols-only face is
# what nerd-icons/doom-modeline render from. `nerd-icons-install-fonts` would
# download these at runtime, which the air-gapped VM cannot do.
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/local/share/fonts/NerdFonts \
    && for f in Hack NerdFontsSymbolsOnly; do \
         curl -fsSL -o "/tmp/$f.zip" \
           "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/$f.zip" \
         && unzip -q -o "/tmp/$f.zip" -d /usr/local/share/fonts/NerdFonts \
         && rm "/tmp/$f.zip"; \
       done \
    && fc-cache -f

# ---------------------------------------------------------------------------
# Go toolchain + the binaries Doom's :lang go module shells out to
# ---------------------------------------------------------------------------
ENV GOPATH=/opt/go \
    GOTOOLCHAIN=local \
    PATH=/usr/local/go/bin:/opt/go/bin:$PATH
# Each `go install ...@latest` must be its own invocation -- Go refuses to
# resolve @latest for packages spanning different modules in one command.
RUN GO_VERSION="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)" \
    && curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" \
       | tar -C /usr/local -xz \
    && for pkg in \
         golang.org/x/tools/gopls@latest \
         golang.org/x/tools/cmd/goimports@latest \
         github.com/go-delve/delve/cmd/dlv@latest \
         mvdan.cc/gofumpt@latest \
         github.com/cweill/gotests/gotests@latest \
         github.com/fatih/gomodifytags@latest; do \
         GOBIN=/usr/local/bin go install "$pkg" || exit 1; \
       done \
    && go clean -modcache \
    && rm -rf /root/.cache/go-build

# ---------------------------------------------------------------------------
# Rust toolchain + rust-analyzer (config.el pins the server command to the
# bare `rust-analyzer` name, so it must be on PATH). rust-src is required for
# rust-analyzer to resolve std.
# ---------------------------------------------------------------------------
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal \
          -c rust-analyzer -c rust-src -c clippy -c rustfmt \
    && chmod -R a+rwX /opt/cargo /opt/rustup

# ---------------------------------------------------------------------------
# Node -- home of most language servers. `ansible-language-server` is the one
# actually wired up today: config.el starts it (lsp-mode's `ansible-ls' client)
# in YAML buffers where Doom's :tools ansible module has turned on
# `ansible-mode'. It registers itself as an add-on client, so yaml-language-server
# below is started alongside it there. The rest are staged for the day a +lsp
# flag gets added, and cost nothing but image size.
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -C /usr/local --strip-components=1 -xJ \
    && npm install -g --no-fund --no-audit \
         @ansible/ansible-language-server \
         yaml-language-server \
         bash-language-server \
         vscode-langservers-extracted \
    && npm cache clean --force

# ---------------------------------------------------------------------------
# Terraform + terraform-ls. lsp-mode's `tfmls' client looks for `terraform-ls'
# on PATH; `terraform' itself backs the :tools terraform module's `SPC m'
# commands (init/plan/apply/...) and its doctor check. Taken as release zips
# rather than through the HashiCorp apt repo so the versions are pinned above
# and no extra key/repo is left configured in the image.
# ---------------------------------------------------------------------------
RUN for pair in "terraform:${TERRAFORM_VERSION}" "terraform-ls:${TERRAFORM_LS_VERSION}"; do \
        name="${pair%%:*}"; version="${pair##*:}"; \
        curl -fsSL -o /tmp/hc.zip \
          "https://releases.hashicorp.com/${name}/${version}/${name}_${version}_linux_amd64.zip" \
        && unzip -q -o /tmp/hc.zip -d /usr/local/bin "$name" \
        && rm /tmp/hc.zip || exit 1; \
    done \
    && chmod 755 /usr/local/bin/terraform /usr/local/bin/terraform-ls

# ---------------------------------------------------------------------------
# Python-packaged tooling: linters for :checkers syntax, plus Ansible itself
# (PEP 668 forbids system-wide pip, so pipx).
#
# `--include-deps` is required for ansible: the `ansible` distribution is just
# the collection bundle and declares no console scripts of its own -- the
# `ansible`/`ansible-playbook`/`ansible-galaxy` binaries come from its
# ansible-core dependency. The full bundle rather than bare ansible-core so
# FQCN completion covers the community collections offline.
# ansible-language-server shells out to both `ansible` and `ansible-lint`.
# ---------------------------------------------------------------------------
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin
RUN pipx install ruff \
    && pipx install mypy \
    && pipx install yamllint \
    && pipx install --include-deps ansible \
    && pipx install ansible-lint

# ---------------------------------------------------------------------------
# Optional .NET SDK (see WITH_DOTNET above)
# ---------------------------------------------------------------------------
RUN if [ "$WITH_DOTNET" = "1" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends dotnet-sdk-8.0 \
        && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# ---------------------------------------------------------------------------
# Doom itself, pinned. Cloned rather than COPY'd: the working tree in ./emacs.d
# carries ~450MB of straight/ and eln-cache/ built against the HOST's Emacs,
# which would be both wrong and dead weight inside this image.
# ---------------------------------------------------------------------------
# The sources/doom+ module tree is a submodule, so its commit is pinned by
# DOOM_REF itself -- `submodule update` resolves it to 5a44cf7bd, matching
# your working tree.
RUN git clone https://github.com/doomemacs/doomemacs /emacs.d \
    && git -C /emacs.d checkout "$DOOM_REF" \
    && git -C /emacs.d submodule update --init --recursive

# ---------------------------------------------------------------------------
# Tree-sitter grammars. Must come AFTER the clone above, which requires an
# empty /emacs.d.
#
# Doom v3 uses Emacs' built-in treesit and installs grammars on demand -- a
# network operation. They are compiled here instead, into
# $EMACSDIR/tree-sitter, which treesit searches by default (after
# `treesit-extra-load-path`, before the system directories).
#
# The "cannot be located" warnings this prints are expected: `emacs -Q` leaves
# `user-emacs-directory' at /root/.emacs.d, so treesit's post-install
# verification looks there rather than at the out-dir it just wrote to. At
# runtime the wrapper sets --init-directory=/emacs.d and the paths agree.
# ---------------------------------------------------------------------------
RUN mkdir -p /emacs.d/tree-sitter \
    && emacs -Q --batch --eval "(progn \
         (setq treesit-language-source-alist \
               '((bash \"https://github.com/tree-sitter/tree-sitter-bash\") \
                 (c \"https://github.com/tree-sitter/tree-sitter-c\") \
                 (cpp \"https://github.com/tree-sitter/tree-sitter-cpp\") \
                 (c-sharp \"https://github.com/tree-sitter/tree-sitter-c-sharp\") \
                 (cmake \"https://github.com/uyha/tree-sitter-cmake\") \
                 (dockerfile \"https://github.com/camdencheek/tree-sitter-dockerfile\") \
                 (elisp \"https://github.com/Wilfred/tree-sitter-elisp\") \
                 (go \"https://github.com/tree-sitter/tree-sitter-go\") \
                 (gomod \"https://github.com/camdencheek/tree-sitter-go-mod\") \
                 (gowork \"https://github.com/omertuc/tree-sitter-go-work\") \
                 (json \"https://github.com/tree-sitter/tree-sitter-json\") \
                 (make \"https://github.com/tree-sitter-grammars/tree-sitter-make\") \
                 (markdown \"https://github.com/tree-sitter-grammars/tree-sitter-markdown\" nil \"tree-sitter-markdown/src\") \
                 (markdown-inline \"https://github.com/tree-sitter-grammars/tree-sitter-markdown\" nil \"tree-sitter-markdown-inline/src\") \
                 (org \"https://github.com/milisims/tree-sitter-org\") \
                 (python \"https://github.com/tree-sitter/tree-sitter-python\") \
                 (rust \"https://github.com/tree-sitter/tree-sitter-rust\") \
                 (toml \"https://github.com/tree-sitter-grammars/tree-sitter-toml\") \
                 (yaml \"https://github.com/tree-sitter-grammars/tree-sitter-yaml\"))) \
         (dolist (lang (mapcar #'car treesit-language-source-alist)) \
           (message \"Installing grammar: %s\" lang) \
           (treesit-install-language-grammar lang \"/emacs.d/tree-sitter\")))"

# Private config last -- it is what changes most often, so everything above
# stays cached when you edit config.el.
COPY doom /doom

# ---------------------------------------------------------------------------
# Install and sync Doom. -e skips the envvar file (exec-path-from-shell in
# config.el covers PATH at runtime, and a build-time env file would bake
# HOME=/root). -! auto-accepts prompts.
# ---------------------------------------------------------------------------
RUN /emacs.d/bin/doom -! install --no-config --no-env --no-hooks \
    && /emacs.d/bin/doom -! sync -e -j "$(nproc)" $DOOM_AOT

# vterm builds its native module the first time it is loaded, which would
# otherwise happen on the air-gapped VM. Force it here instead.
#
# `--init-directory' is deliberately NOT used: Doom does not bootstrap itself
# under `--batch', so its init would not run and straight's build directory
# would never reach `load-path' -- `(require 'vterm)' then fails with
# "Cannot open load file". Point at the built package directly instead. The
# glob keeps the Emacs version out of the path (straight builds into
# build-<version>/), and vterm.el pulls in nothing outside Emacs' own tree, so
# its own directory is all `load-path' needs.
RUN emacs --batch \
      --eval "(progn \
        (dolist (dir (file-expand-wildcards \"/doom-local/straight/build-*/vterm\")) \
          (add-to-list 'load-path dir)) \
        (setq vterm-always-compile-module t) \
        (require 'vterm))" \
    && ls /doom-local/straight/build-*/vterm/vterm-module.so >/dev/null

# Every mutable path must be writable by the unprivileged host user that
# distrobox maps in -- their UID is unknown at build time. This covers the
# package cache, eln-cache, autosaves, recentf, projectile's cache, and
# custom.el (which Emacs' Custom interface writes to $DOOMDIR).
RUN chmod -R a+rwX /doom-local /doom /emacs.d

# ---------------------------------------------------------------------------
# Launchers. `emacs` here shadows /usr/bin/emacs via PATH order and pins the
# init directory, so the host's ~/.emacs.d can never be picked up.
# ---------------------------------------------------------------------------
RUN printf '%s\n' \
      '#!/bin/sh' \
      'exec /usr/bin/emacs --init-directory="${EMACSDIR:-/emacs.d}" "$@"' \
      > /usr/local/bin/emacs \
    && printf '%s\n' \
      '#!/bin/sh' \
      'exec /emacs.d/bin/doom "$@"' \
      > /usr/local/bin/doom \
    && chmod 755 /usr/local/bin/emacs /usr/local/bin/doom

# Same variables for interactive shells, so `doom` and `emacsclient` behave
# whether the user lands in bash or fish.
#
# The PATH entries are not redundant with ENV above: config.el runs
# `exec-path-from-shell-initialize' with '-l', which REPLACES Emacs' exec-path
# with the PATH of a login fish shell. Fish never reads /etc/profile, so
# without this the Go and Cargo directories would be stripped and
# `executable-find' would fail to turn up rust-analyzer or gopls.
RUN printf '%s\n' \
      'export EMACSDIR=/emacs.d' \
      'export DOOMDIR=/doom' \
      'export DOOMLOCALDIR=/doom-local/' \
      'export PATH="/usr/local/go/bin:/opt/go/bin:/opt/cargo/bin:$PATH"' \
      > /etc/profile.d/doom.sh \
    && mkdir -p /etc/fish/conf.d \
    && printf '%s\n' \
      'set -gx EMACSDIR /emacs.d' \
      'set -gx DOOMDIR /doom' \
      'set -gx DOOMLOCALDIR /doom-local/' \
      'fish_add_path -g /usr/local/go/bin /opt/go/bin /opt/cargo/bin' \
      > /etc/fish/conf.d/doom.fish
