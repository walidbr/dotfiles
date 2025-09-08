# Completion generator: reads ~/.bookmarks and feeds candidates to compadd
_bookmarks_completion() {
  local bmfile="$HOME/.bookmarks"
  if [[ ! -r "$bmfile" ]]; then
    _message "Bookmarks file not found: $bmfile"
    return 1
  fi

  local -a urls descs
  local label url
  # Read first two whitespace-separated fields per line, skip blanks/comments
  while read -r label url _; do
    [[ -z "$label" || -z "$url" ]] && continue
    [[ "$label" = \#* ]] && continue
    descs+=("$label")
    urls+=("$url")
  done < "$bmfile"

#   echo "descs: $descs"
#   echo "urls: $urls"

  # Provide URL candidates with labels as descriptions (fzf-tab shows these)
  compadd -d descs -a urls
}

# The 'bookmark' function: opens a URL
bookmark() {
    echo "Bookmark function called with argument: $*"
#   local url_to_open="$1"
#   if [[ -n "$url_to_open" ]]; then
#     if command -v open >/dev/null 2>&1; then
    #   open "$url_to_open"
#     elif command -v xdg-open >/dev/null 2>&1; then
#       xdg-open "$url_to_open"
#     else
#       print -r -- "Could not find a command to open the URL."
#       return 1
#     fi
#   fi
}

# Wire up completion: first argument gets our custom completion
_bookmark_comp() {
  _arguments \
    '1:bookmark URL:_bookmarks_completion' \
    '*:: :->rest'
}

compdef _bookmark_comp bookmark