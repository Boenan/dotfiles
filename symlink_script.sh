#!/bin/bash

DOTFILES_DIR=$(pwd)
# DOT_CONFIG_FOLDERS="aerospace asdf fish ghostty helix k9s nvim"
# DOT_CONFIG_FOLDERS="fish ghostty helix k9s starship tmux hypr waybar walker"
# DOT_CONFIG_FOLDERS="fish ghostty helix k9s starship tmux broot vim"
DOT_CONFIG_FOLDERS="fish ghostty k9s starship tmux broot vim sway dunst"
DOT_CONFIG_HOME="$HOME/.config"

for folder in $DOT_CONFIG_FOLDERS; do
  SOURCE="$DOTFILES_DIR/$folder"
  DESTINATION="$DOT_CONFIG_HOME/${folder#$DOTFILES_DIR/}"

  rm -rf $DESTINATION
  
  echo "Creating symlink from $SOURCE to $DESTINATION"
  ln -sf $SOURCE $DESTINATION
done

ln -sf $DOTFILES_DIR/asdf/.tool-versions ~/.tool-versions

# waybar uses a folder with a different name
rm -rf $DOT_CONFIG_HOME/waybar
ln -sf $DOTFILES_DIR/waybar-fedora $DOT_CONFIG_HOME/waybar

# Do not start nm-applet; the waybar popup replaces it
mkdir -p $DOT_CONFIG_HOME/autostart
ln -sf $DOTFILES_DIR/autostart/nm-applet.desktop $DOT_CONFIG_HOME/autostart/nm-applet.desktop

# Hide the blueman tray icon; the waybar popup replaces it
gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"
