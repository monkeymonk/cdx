#compdef cdx

_cdx_up_levels() {
  compadd -Q -- {1..9}
}

_cdx_up_level_or_dir() {
  _alternative \
    'levels:level:_cdx_up_levels' \
    'dirs:directory:_directories'
}

_cdx_up_subpath() {
  local cur="${words[$CURRENT]}"
  local num="${cur%%/*}"
  local rest="${cur#*/}"
  local up_prefix=""
  local i
  local -a dirs

  for (( i = 1; i <= num; i++ )); do
    up_prefix+="../"
  done

  dirs=(${up_prefix}${rest}*(/N))
  dirs=(${dirs#${up_prefix}})
  dirs=(${dirs/#/${num}/})
  compadd -Q -S / -- $dirs
}

_cdx_up_at_level() {
  local num="$1"
  local up_prefix=""
  local i
  local -a dirs

  for (( i = 1; i <= num; i++ )); do
    up_prefix+="../"
  done

  dirs=(${up_prefix}*(/N))
  dirs=(${dirs#${up_prefix}})
  dirs=(${dirs/#/${num}/})
  compadd -Q -S / -- $dirs
}

_cdx() {
  # Handle -N/subpath shorthand before _arguments
  if [[ "${words[$CURRENT]}" == -<->/* ]]; then
    local cur="${words[$CURRENT]}"
    local num="${${cur#-}%%/*}"
    local rest="${cur#*-${num}/}"
    local up_prefix=""
    local i
    local -a dirs

    for (( i = 1; i <= num; i++ )); do
      up_prefix+="../"
    done

    dirs=(${up_prefix}${rest}*(/N))
    dirs=(${dirs#${up_prefix}})
    dirs=(${dirs/#/-${num}/})
    compadd -Q -S / -- $dirs
    return
  fi

  # Handle -N shorthand (no slash yet) — show dirs at that level
  if [[ "${words[$CURRENT]}" == -<-> ]]; then
    local num="${words[$CURRENT]#-}"
    local up_prefix=""
    local i
    local -a dirs

    for (( i = 1; i <= num; i++ )); do
      up_prefix+="../"
    done

    dirs=(${up_prefix}*(/N))
    dirs=(${dirs#${up_prefix}})
    dirs=(${dirs/#/-${num}/})
    compadd -Q -S / -- $dirs
    return
  fi

  _arguments \
    '-i[inspect mode — preview without changing directory]' \
    '--up[go up N parent levels]:level[/subpath]:->up_target' \
    '(-h --help)'{-h,--help}'[show help]' \
    '(-v --version)'{-v,--version}'[show version]' \
    '1:directory:_directories'

  case "$state" in
    up_target)
      if [[ "${words[$CURRENT]}" == <->/* ]]; then
        _cdx_up_subpath
      elif [[ "${words[$CURRENT]}" == <-> ]]; then
        _cdx_up_at_level "${words[$CURRENT]}"
      else
        _cdx_up_level_or_dir
      fi
      ;;
  esac
}

_cdx
