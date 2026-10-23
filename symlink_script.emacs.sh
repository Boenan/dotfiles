#!/bin/bash
# Link the dotfiles that containerfile.emacs bakes into the image (fish,
# starship, tmux) into ~/.config. Run it inside the emacs distrobox:
#
#   distrobox enter emacs -- link-dotfiles
#
# distrobox bind-mounts the host $HOME, so the links land in the host's
# ~/.config and point into /dotfiles, which exists only in the container.
# An existing folder that is not a link is moved to <folder>.bak.<date>, not
# deleted.
set -euo pipefail

DOTFILES_DIR=${DOTFILES_DIR:-/dotfiles}
DOT_CONFIG_FOLDERS="fish starship tmux"
DOT_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$DOT_CONFIG_HOME"

for folder in $DOT_CONFIG_FOLDERS; do
  SOURCE="$DOTFILES_DIR/$folder"
  DESTINATION="$DOT_CONFIG_HOME/$folder"

  if [[ -e $DESTINATION && ! -L $DESTINATION ]]; then
    BACKUP="$DESTINATION.bak.$(date +%Y%m%d%H%M%S)"
    echo "Moving $DESTINATION to $BACKUP"
    mv "$DESTINATION" "$BACKUP"
  fi

  echo "Creating symlink from $SOURCE to $DESTINATION"
  ln -sfn "$SOURCE" "$DESTINATION"
done
