#!/usr/bin/env bash
# cdx — extensible cd wrapper

__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()
__CDX_VERSION="0.2.0"

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

_cdx_dispatch() {
  local mode="$1" dir="$2"
  local fn
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    "$fn" "$mode" "$dir"
  done
  for fn in "${__CDX_HOOKS_ASYNC[@]}"; do
    ("$fn" "$mode" "$dir" &>/dev/null) &
  done
}

cdx() {
  local inspect=0
  local up_mode=0
  local up_spec=""
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      --up)
        up_mode=1
        if [[ "${2-}" =~ ^[0-9] ]]; then
          up_spec="$2"; shift
        fi
        shift ;;
      -[0-9]*)
        up_mode=1
        up_spec="${1#-}"
        shift ;;
      -h|--help) _cdx_usage; return 0 ;;
      -v|--version) _cdx_version; return 0 ;;
      --) shift; args+=("$@"); break ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  if [[ $up_mode -eq 1 ]]; then
    local count=1 subpath=""
    if [[ -n "$up_spec" ]]; then
      local num="${up_spec%%/*}"
      if [[ "$num" =~ ^[0-9]+$ ]]; then
        count="$num"
        [[ "$up_spec" == */* ]] && subpath="${up_spec#*/}"
      fi
    fi
    local target=""
    local i
    local loops=$count
    [[ -n "$subpath" ]] && loops=$(( count + 1 ))
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

  local target="${args[0]:-$HOME}"
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
  else
    builtin cd "$resolved" || return 1
  fi

  local cdxrc="$resolved/.cdxrc"
  [[ -f "$cdxrc" ]] && source "$cdxrc"

  _cdx_dispatch "$mode" "$resolved"
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
