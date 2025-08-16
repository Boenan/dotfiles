#!/bin/bash

DOTFILES_DIR=$(pwd)
# DOT_CONFIG_FOLDERS="aerospace asdf fish ghostty helix k9s nvim"
DOT_CONFIG_FOLDERS="aerospace fish ghostty helix k9s sketchybar starship tmux"
DOT_CONFIG_HOME="$HOME/.config"

for folder in $DOT_CONFIG_FOLDERS; do
  SOURCE="$DOTFILES_DIR/$folder"
  DESTINATION="$DOT_CONFIG_HOME/${folder#$DOTFILES_DIR/}"

  rm -rf $DESTINATION
  
  echo "Creating symlink from $SOURCE to $DESTINATION"
  ln -sf $SOURCE $DESTINATION
done

ln -sf $DOTFILES_DIR/asdf/.tool-versions ~/.tool-versions
