if status is-interactive
    # Commands to run in interactive sessions can go here
end

# zoxide
zoxide init --cmd cd fish | source

# atuin
atuin init fish --disable-up-arrow | source
bind up history-search-backward

# starship
starship init fish | source
# source (brew --prefix asdf)/libexec/asdf.fish
if command -v brew >/dev/null
    set -l brew_asdf (brew --prefix asdf)/libexec/asdf.fish
    if test -f $brew_asdf
        source $brew_asdf
    end
end

set -gx EDITOR helix
set -gx VISUAL helix
set -gx KUBE_EDITOR helix
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
