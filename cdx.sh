#!/usr/bin/env bash
# cdx — extensible cd wrapper

__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()
__CDX_VERSION="0.2.2"

_cdx_usage() {
  printf "cdx — extensible cd wrapper\nVersion: v%s\n" "$__CDX_VERSION"
  cat <<'USAGE'
Usage:
  cdx [options] [dir]
  cdx -i [dir]
  cdx --up [N[/subpath]]
  cdx -N[/subpath]

Options:
  -i            Inspect mode (run hooks without changing directory)
  --up [N]      Go up N parent levels (default: 1)
  -N            Shorthand for --up N (e.g. -3, -2/src)
  -h, --help    Show this help message
  -v, --version Show the cdx version

Examples:
  cdx /tmp
  cdx -i /tmp
  cdx --up
  cdx --up 2
  cdx --up 2/src
  cdx -3
  cdx -2/src
  cdx -- /path
USAGE
}

_cdx_version() {
  printf "cdx v%s\n" "$__CDX_VERSION"
}

cdx_register_hook() {
  local type="$1" fn="$2"
  case "$type" in
    sync)
      [[ " ${__CDX_HOOKS_SYNC[*]} " == *" $fn "* ]] && return 0
      __CDX_HOOKS_SYNC+=("$fn") ;;
    async)
      [[ " ${__CDX_HOOKS_ASYNC[*]} " == *" $fn "* ]] && return 0
      __CDX_HOOKS_ASYNC+=("$fn") ;;
    *)     echo "cdx: unknown hook type: $type" >&2; return 1 ;;
  esac
}

cdx() {
  local inspect=0
  local up_mode=0
  local up_spec=""
  local dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      --up)
        up_mode=1
        case "${2-}" in [0-9]*) up_spec="$2"; shift ;; esac
        shift ;;
      -h|--help) _cdx_usage; return 0 ;;
      -v|--version) _cdx_version; return 0 ;;
      --) shift; dir="${1-}"; break ;;
      -[0-9]*) up_mode=1; up_spec="${1#-}"; shift ;;
      -*)
        # zsh may not match -[0-9]* above; check second char without character class
        case "${1:1:1}" in
          0|1|2|3|4|5|6|7|8|9) up_mode=1; up_spec="${1#-}" ;;
          *) dir="${dir:-$1}" ;;
        esac
        shift ;;
      *)  dir="${dir:-$1}"; shift ;;
    esac
  done

  if [[ $up_mode -eq 1 ]]; then
    local count=1 subpath=""
    if [[ -n "$up_spec" ]]; then
      local num="${up_spec%%/*}"
      if [[ -n "$num" ]] && (( num > 0 )) 2>/dev/null; then
        count="$num"
        [[ "$up_spec" == */* ]] && subpath="${up_spec#*/}"
      fi
    fi
    local target=""
    local i
    local loops=$count
    for ((i = 0; i < loops; i++)); do target="../$target"; done
    [[ -n "$subpath" ]] && target="${target}${subpath}"
    [[ -z "$target" ]] && target=".."
    if [[ $inspect -eq 1 ]]; then
      cdx -i "$target"
    else
      cdx "$target"
    fi
    return
  fi

  local target="${dir:-$HOME}"
  local resolved_target=""

  if [[ ! -d "$target" ]] && command -v zoxide &>/dev/null; then
    resolved_target="$(zoxide query -- "$target" 2>/dev/null)"
  fi
  [[ -z "$resolved_target" ]] && resolved_target="$target"

  local resolved
  resolved="$(builtin cd "$resolved_target" 2>/dev/null && pwd)" || {
    echo "cdx: no such directory: $target" >&2
    return 1
  }

  local mode="enter"
  if [[ $inspect -eq 1 ]]; then
    mode="inspect"
    echo "$resolved"
  else
    builtin cd "$resolved" || return 1
  fi

  local cdxrc="$resolved/.cdxrc"
  [[ -f "$cdxrc" ]] && source "$cdxrc"

  # Dispatch hooks inline
  local fn
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    "$fn" "$mode" "$resolved"
  done
  for fn in "${__CDX_HOOKS_ASYNC[@]}"; do
    ("$fn" "$mode" "$resolved" &>/dev/null) &
  done
}

_cdx_init() {
  local config_dir="${CDX_CONFIG_DIR:-$HOME/.config/cdx}"
  local config="$config_dir/config.sh"
  [[ -f "$config" ]] && source "$config"

  local hooks_dir="$config_dir/hooks"
  local name
  for name in "${CDX_HOOKS_ENABLED[@]}"; do
    local hook_file="$hooks_dir/${name}.sh"
    if [[ -f "$hook_file" ]]; then
      source "$hook_file"
    else
      echo "cdx: hook not found: $name" >&2
    fi
  done
}

_cdx_init
