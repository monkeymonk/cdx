# cdx bash completion

_cdx_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local have_i=0
  local w

  for w in "${COMP_WORDS[@]}"; do
    [[ "$w" == "-i" ]] && have_i=1
  done

  # After --up, complete level numbers and subpaths
  if [[ "$prev" == "--up" ]]; then
    if [[ "$cur" =~ ^[0-9]+/ ]]; then
      local num="${cur%%/*}"
      local rest="${cur#*/}"
      local partial_path
      partial_path="$(printf '../%.0s' $(seq 1 "$num"))$rest"
      COMPREPLY=($(compgen -d -- "$partial_path" | sed "s|^../*/|${num}/|"))
      return
    fi
    local nums
    nums="$(printf '%s\n' {1..9})"
    COMPREPLY=($(compgen -W "$nums" -- "$cur"))
    COMPREPLY+=($(compgen -d -- "$cur"))
    return
  fi

  # -N shorthand: current word looks like -digit
  if [[ "$cur" =~ ^-[0-9] ]]; then
    local num="${cur#-}"
    num="${num%%/*}"
    if [[ "$cur" == */* ]]; then
      local rest="${cur#*-${num}/}"
      local partial_path
      partial_path="$(printf '../%.0s' $(seq 1 "$num"))$rest"
      COMPREPLY=($(compgen -d -- "$partial_path" | sed "s|^\.\./*/|${num}/|"))
    else
      COMPREPLY=($(compgen -W "$(printf -- '-%s\n' {1..9})" -- "$cur"))
    fi
    return
  fi

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "-i --up -h --help -v --version" -- "$cur"))
    return
  fi

  if [[ "$prev" == "-i" || "$have_i" -eq 1 ]]; then
    COMPREPLY=($(compgen -d -- "$cur"))
    return
  fi

  COMPREPLY=($(compgen -W "-i --up -h --help -v --version" -- "$cur"))
  COMPREPLY+=($(compgen -d -- "$cur"))
}

complete -F _cdx_complete cdx
