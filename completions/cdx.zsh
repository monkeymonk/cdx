#compdef cdx up

_cdx() {
  _arguments \
    '-i[inspect mode — preview without changing directory]' \
    '1:directory:_directories'
}

_up() {
  _arguments \
    '-i[inspect mode]' \
    '1:N[/subpath]:_directories'
}

case "$service" in
  cdx) _cdx ;;
  up)  _up ;;
esac
