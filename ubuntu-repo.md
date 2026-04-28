# Ubuntu 24.04 Package Repository Information

This document categorizes the packages installed in `containerfile.ubuntu` by their repository source or installation method.

## Main Repository
These packages are officially supported by Canonical and receive security updates for the full lifecycle of the release.

| Package | Approved |
| :--- | :--- |
| `apt-transport-https` | Yes |
| `ca-certificates` | Yes |
| `curl` | Yes |
| `fuse-overlayfs` | Yes |
| `git` | Yes |
| `gnupg` / `gpg` | Yes |
| `jq` |Yes |
| `locales` |Yes |
| `openssh-client` | Yes |
| `sudo` | Yes |
| `tar` | Yes |
| `tmux` | Yes |
| `unzip` | Yes |
| `wget` | Yes |
| `xz-utils` | Yes |

## Universe Repository
These community-maintained packages require the `universe` repository to be enabled.

| Package | Approved |
| :--- | :--- |
| `bat` | No | 
| `bats` | No |
| `crun` | Yes |
| `fish` | No |
| `fzf` | No |
| `glab` | Yes |
| `npm` | Yes? |
| `podman` | Yes |
| `ripgrep` | No |
| `wl-clipboard` | No |
| `zoxide` | No |

## Third-Party APT Repositories
These packages are installed via `apt` after adding external GPG keys and source lists.

| Package | Approved | Source |
| :--- | :--- | :--- |
| `eza` | No | [eza-community/eza](https://github.com/eza-community/eza) |
| `helm` | Yes | [helm/helm](https://github.com/helm/helm) |
| `kubectl` | Yes | [kubernetes/kubectl](https://github.com/kubernetes/kubectl) |
| `ghostty` | No | [ghostty-org/ghostty](https://github.com/ghostty-org/ghostty) |

## Manually Installed / Other Sources
These tools are installed via direct binary downloads, installation scripts, or other package managers like `npm`.

| Package | Approved | Source |
| :--- | :--- | :--- | :--- |
| `starship` | No | [starship/starship](https://github.com/starship/starship) |
| `atuin` | No | [atuinsh/atuin](https://github.com/atuinsh/atuin) |
| `broot` | No | [Canop/broot](https://github.com/Canop/broot) |
| `yq` | No | [mikefarah/yq](https://github.com/mikefarah/yq) |
| `hx` (Helix) | No | [helix-editor/helix](https://github.com/helix-editor/helix) |
| `nickel` / `nls` | No | [tweag/nickel](https://github.com/tweag/nickel) |
| `k9s` | Yes | [derailed/k9s](https://github.com/derailed/k9s) |
| `kubeseal` | Yes | [sealed-secrets/sealed-secrets](https://github.com/sealed-secrets/sealed-secrets) |
| `argocd` | Yes | [argoproj/argo-cd](https://github.com/argoproj/argo-cd) |
| `istioctl` | Yes | [istio/istio](https://github.com/istio/istio) |
| `kubelogin` | Yes | [int128/kubelogin](https://github.com/int128/kubelogin) |
| `oras` | Yes | [oras-project/oras](https://github.com/oras-project/oras) |
| `kctx` | No | [Boenan/kctx](https://github.com/Boenan/kctx) |
| `bash-language-server` | Yes | [bash-lsp/bash-language-server](https://github.com/bash-lsp/bash-language-server) |
| `vscode-langservers-extracted` | Yes | [hrsh7th/vscode-langservers-extracted](https://github.com/hrsh7th/vscode-langservers-extracted) |
| `yaml-language-server` | Yes | [redhat-developer/yaml-language-server](https://github.com/redhat-developer/yaml-language-server) |
