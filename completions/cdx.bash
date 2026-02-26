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
      local prefix
      prefix="$(printf '../%.0s' $(seq 1 "$num"))"
      compopt -o nospace 2>/dev/null
      COMPREPLY=()
      while IFS= read -r d; do
        [[ -n "$d" ]] && COMPREPLY+=("${num}/${d#"$prefix"}/")
      done < <(compgen -d -- "${prefix}${rest}")
      return
    fi
    if [[ "$cur" =~ ^[0-9]+$ ]]; then
      local prefix
      prefix="$(printf '../%.0s' $(seq 1 "$cur"))"
      compopt -o nospace 2>/dev/null
      COMPREPLY=()
      while IFS= read -r d; do
        [[ -n "$d" ]] && COMPREPLY+=("${cur}/${d#"$prefix"}/")
      done < <(compgen -d -- "$prefix")
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
    local prefix
    prefix="$(printf '../%.0s' $(seq 1 "$num"))"
    if [[ "$cur" == */* ]]; then
      local rest="${cur#*-${num}/}"
      compopt -o nospace 2>/dev/null
      COMPREPLY=()
      while IFS= read -r d; do
        [[ -n "$d" ]] && COMPREPLY+=("-${num}/${d#"$prefix"}/")
      done < <(compgen -d -- "${prefix}${rest}")
    elif [[ "$cur" =~ ^-[0-9]+$ ]]; then
      compopt -o nospace 2>/dev/null
      COMPREPLY=()
      while IFS= read -r d; do
        [[ -n "$d" ]] && COMPREPLY+=("-${num}/${d#"$prefix"}/")
      done < <(compgen -d -- "$prefix")
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
