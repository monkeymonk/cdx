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
  local base=""
  local i
  local -a dirs

  for (( i = 1; i <= num; i++ )); do
    base+="../"
  done
  base+="$rest"

  dirs=(${base}*(/N))
  dirs=(${dirs#$base})
  dirs=(${dirs/#/${num}/})
  compadd -Q -- $dirs
}

_cdx() {
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
      else
        _cdx_up_level_or_dir
      fi
      ;;
  esac
}

_cdx
