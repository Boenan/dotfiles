if status is-interactive
    # atuin
    atuin init fish --disable-up-arrow | source
    bind up history-search-backward
end

fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/.emacs.d/bin

# zoxide
zoxide init --cmd cd fish | source

# starship
starship init fish | source
# source (brew --prefix asdf)/libexec/asdf.fish
if command -v brew >/dev/null
    set -l brew_asdf (brew --prefix asdf)/libexec/asdf.fish
    if test -f $brew_asdf
        source $brew_asdf
    end
end

# DOTFILES_EDITOR is set by the emacs container (containerfile.emacs).
set -l editor vim
set -q DOTFILES_EDITOR; and set editor $DOTFILES_EDITOR
set -gx EDITOR $editor
set -gx VISUAL $editor
set -gx KUBE_EDITOR $editor
set -gx HELIX_RUNTIME "$HOME/.config/helix/runtime"
set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"

# The next line updates PATH for the Google Cloud SDK.
if not command -v gcloud >/dev/null
    set -l gcloud_paths \
        "$HOME/google-cloud-sdk/path.fish.inc" \
        "/usr/share/google-cloud-sdk/path.fish.inc" \
        "/opt/google-cloud-sdk/path.fish.inc"

    # Add Homebrew path only if brew exists
    if command -v brew >/dev/null
        set -a gcloud_paths (brew --prefix)/share/google-cloud-sdk/path.fish.inc
    end

    for path in $gcloud_paths
        if test -f "$path"
            source "$path"
            break # Stop once we find it
        end
    end
end
