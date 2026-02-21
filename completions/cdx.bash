# cdx bash completion

_cdx_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "${COMP_WORDS[0]}" in
    up)
      if [[ "$cur" =~ ^[0-9] ]]; then
        local num="${cur%%/*}"
        local rest="${cur#*/}"
        if [[ "$cur" == */* ]]; then
          local partial_path
          partial_path="$(printf '../%.0s' $(seq 1 "$num"))$rest"
          COMPREPLY=($(compgen -d -- "$partial_path" | sed "s|^../*/|${num}/|"))
        fi
      else
        COMPREPLY=($(compgen -d -- "$cur"))
      fi
      ;;
    cdx)
      COMPREPLY=($(compgen -d -- "$cur"))
      ;;
  esac
}

complete -F _cdx_complete cdx
complete -F _cdx_complete up
