# Create new session and if alread exists attach to it
function tmux::new
    set -l session $argv[1]
    if test -z "$session"
        tmux::new (string join "" T (date +%s))
    else
        tmux new-session -d -s $session
        tmux -2 attach-session -t $session || tmux -2 switch-client -t $session
    end
end

function tmux::attach
    set -l session $argv[1]
    if test -z "$session"
        tmux attach-session || tmux::new
    else
        tmux attach-session -t $session || tmux::new $session
    end
end

function tmux::search
    set -l session (tmux list-sessions | fzf | cut -d: -f1)
    if test -z "$TMUX"
        tmux attach-session -t $session
    else
        tmux switch -t $session
    end
end

function tk --description "Kill a specific tmux session"
    set -l session $argv[1]

    if test -z "$session"
        echo "Usage: tk <session-name>"
        return 1
    end

    if tmux has-session -t "$session" 2>/dev/null
        tmux kill-session -t "$session"
        echo "Session '$session' killed."
    else
        echo "Error: No session named '$session' found."
    end
end
