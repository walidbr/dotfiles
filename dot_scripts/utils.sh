function note() {
    # Check if a specific message was provided as an argument.
    if [ $# -gt 0 ]; then
        # If arguments are provided, append them directly.
        echo "----- date: $(date +'%Y-%m-%d %H:%M:%S') -----" >> "$HOME/Notes.txt"
        echo "$@" >> "$HOME/Notes.txt"
        echo "" >> "$HOME/Notes.txt"
    else
        # If no arguments are provided, use gum write to prompt for multi-line input.
        echo "----- date: $(date +'%Y-%m-%d %H:%M:%S') -----" >> "$HOME/Notes.txt"
        gum write --placeholder "Enter your note here..." >> "$HOME/Notes.txt"
        echo "" >> "$HOME/Notes.txt"
    fi
}

source $HOME/.scripts/tools_path.sh
alias c="fzf | xargs code"
alias cdfzf="fzf | xargs cd"
alias kfzf="ps -ef | fzf --multi | awk '{print $2}' | xargs -r kill -9"
alias llama="fabric-ai -s -m codellama:7b"
alias gpt4="fabric-ai -s -m o4-mini"
alias gpt5="fabric-ai -s -m gpt-5-mini"
alias GPT5="fabric-ai -s -m gpt-5"
alias gemini="fabric-ai -s -m gemini-2.5-flash"
alias commit_msg="git diff HEAD~1 | fabric-ai -s -m o4-mini -p acl_commit"
alias gw="gum write --width=200 --height=10"
function search {
  open "https://www.google.com/search?q=$*"
}
source ~/.scripts/sensitive.sh

export GOROOT=$(brew --prefix go)/libexec
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$PATH
#source ~/.fzf_functions
# source $HOME/.scripts/bookmark.sh
export NAVI_PATH=$HOME/.config/navi/cheats
alias nq="navi --query"
alias h="history | fzf | awk '{\$1=\"\"; sub(/^[ \t]+/,\"\"); printf \"%s\", \$0}' | pbcopy"
he() {
  local cmd
  # Pick from history, strip index
  cmd=$(history | fzf | awk '{ $1=""; sub(/^[ \t]+/, ""); print }')
  [[ -n $cmd ]] && eval "$cmd"
}
alias ls="lsd"
alias vi="nvim"

# Path to the fzf-tab plugin
# zinit light Aloxaf/fzf-tab

# If you want to configure fzf-tab further, you can add options like this:
# Set the completion mode to menu
# zstyle ':completion:*' list-colors ''
# zstyle ':completion:*:*:*:*:*' menu select
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls $realpath'
# zstyle -d ':fzf-tab:complete:cd:*' fzf-preview
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --oneline --graph --date=short --color=always --branches | grep --color=never -F " " | fzf-preview-branch-log'
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup



which-completion() {
  local cmd=$1
  local compfunc
  compfunc=$(print -r -- ${(j: :)${(M)${(k)functions}##_${cmd}(|-[^-]#)}})
  if [[ -n $compfunc ]]; then
    echo "$cmd → $compfunc"
  else
    echo "No completion function found for $cmd"
  fi
}

gitsha() {
  local target="$1"
  [ -z "$target" ] && target="."

  local abs repo rel
  abs=$(realpath "$target") || return 1
  repo=$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null) || return 1
  rel="${abs#$repo/}"

  pushd "$repo" >/dev/null || return 1
  git log -n 1 --pretty=format:"%H" -- "$rel" 2>/dev/null
  local rc=$?
  popd >/dev/null || true

  return $rc
}

alias jcli="java -jar ~/apps/jenkins-cli.jar -s https://acl.ml.arm.com/jenkins/"