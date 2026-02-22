#compdef cdx up

_cdx() {
  _arguments \
    '-i[inspect mode — preview without changing directory]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '1:directory:_directories'
}

_up_levels() {
  compadd -Q -- {1..9}
}

_up_level_or_dir() {
  _alternative \
    'levels:level:_up_levels' \
    'dirs:directory:_directories'
}

_up_subpath() {
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

_up() {
  _arguments \
    '-i[inspect mode]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '1:level[/subpath]:->target'

  case "$state" in
    target)
      if [[ "${words[$CURRENT]}" == <->/* ]]; then
        _up_subpath
      else
        _up_level_or_dir
      fi
      ;;
  esac
}

case "$service" in
  cdx) _cdx ;;
  up)  _up ;;
esac
