#!/bin/bash

# install brew package manager
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)

brew install \
  atuin \
  asdf \
  bat \
  colima \
  docker \
  docker-buildx \
  docker-compose \
  kind \
  helmfile \
  k9s \
  eza \
  firefox \
  fzf \
  tmux \
  ghostty \
  fish \
  helix \
  ripgrep \
  zoxide \
  starship

brew install --cask ghostty
brew install --cask nikitabobko/tap/aerospace

brew tap FelixKratz/formulae
brew install sketchybar
brew services start sketchybar

brew install --cask font-hack-nerd-font
