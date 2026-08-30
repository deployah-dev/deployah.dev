# Source after the size tape. VHS zsh has no rc files, so this loads
# Starship and syntax highlighting. nix run .#demo sets STARSHIP_CONFIG
# and ZSH_SYNTAX_HIGHLIGHTING. Wait /λ/ matches the prompt.
Hide
Type `eval "$(starship init zsh)"`
Enter
Type `source "$ZSH_SYNTAX_HIGHLIGHTING"`
Enter
Sleep 200ms
