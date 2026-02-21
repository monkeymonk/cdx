# cdx bash completion

_cdx_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local have_i=0
  local w

  for w in "${COMP_WORDS[@]}"; do
    [[ "$w" == "-i" ]] && have_i=1
  done

  case "${COMP_WORDS[0]}" in
    up)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-i" -- "$cur"))
        return
      fi

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

      if [[ "$prev" == "-i" || "$have_i" -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$nums" -- "$cur"))
        COMPREPLY+=($(compgen -d -- "$cur"))
        return
      fi

      COMPREPLY=($(compgen -W "-i $nums" -- "$cur"))
      COMPREPLY+=($(compgen -d -- "$cur"))
      ;;
    cdx)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-i" -- "$cur"))
        return
      fi

      if [[ "$prev" == "-i" || "$have_i" -eq 1 ]]; then
        COMPREPLY=($(compgen -d -- "$cur"))
        return
      fi

      COMPREPLY=($(compgen -W "-i" -- "$cur"))
      COMPREPLY+=($(compgen -d -- "$cur"))
      ;;
  esac
}

complete -F _cdx_complete cdx
complete -F _cdx_complete up
