# ~/.config/fish/functions/ls.fish

# Recommended default flags:
# -a: show hidden files (all)
# -l: long format
# -g: list group
# --icons: show file icons (requires Nerd Font)
# --git: show git status
# --header: display column headers
# --group-directories-first: list directories before files

function ls --description 'Use eza instead of ls'
    eza -lhg --icons --git --group-directories-first $argv
end

function lsa --description 'Use eza instead of ls'
    eza -alhg --icons --git --group-directories-first $argv
end
