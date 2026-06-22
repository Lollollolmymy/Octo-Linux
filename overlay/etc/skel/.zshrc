export EDITOR=vim
export VISUAL=vim
export PAGER=less

autoload -Uz compinit
compinit

setopt autocd
setopt interactive_comments
setopt prompt_subst

PROMPT='%F{cyan}%n%f@%F{yellow}%m%f %F{blue}%~%f %# '
