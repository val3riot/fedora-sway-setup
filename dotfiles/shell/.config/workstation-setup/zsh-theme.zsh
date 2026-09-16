# Gestito da fedora-workstation-setup. Personalizzazioni: aggiungerle in ~/.zshrc.

# Oh My Zsh viene inizializzato solo se non lo è già. Non altera plugins=(...).
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -r "$ZSH/oh-my-zsh.sh" ]] && (( ! $+functions[omz] )); then
  ZSH_THEME=""
  source "$ZSH/oh-my-zsh.sh"
  WORKSTATION_OMZ_LOADED=1
fi

typeset -a _workstation_plugin_candidates
_workstation_plugin_candidates=(
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
)
for _workstation_plugin in "${_workstation_plugin_candidates[@]}"; do
  if (( ! $+functions[_zsh_autosuggest_start] )) && [[ -r "$_workstation_plugin" ]]; then
    source "$_workstation_plugin"
    break
  fi
done

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# Starship deve precedere syntax-highlighting; quest'ultimo va caricato per ultimo.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=magenta,bold'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=blue,bold'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'

_workstation_plugin_candidates=(
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
)
for _workstation_plugin in "${_workstation_plugin_candidates[@]}"; do
  if (( ! $+functions[_zsh_highlight] )) && [[ -r "$_workstation_plugin" ]]; then
    source "$_workstation_plugin"
    break
  fi
done
unset _workstation_plugin _workstation_plugin_candidates
