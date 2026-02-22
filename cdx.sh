#!/usr/bin/env bash
# cdx — extensible cd wrapper

__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()

_cdx_usage() {
  cat <<'USAGE'
cdx — extensible cd wrapper

Usage:
  cdx [options] [dir]
  cdx -i [dir]
  up [options] [N[/subpath]]

Options:
  -i            Inspect mode (run hooks without changing directory)
  -h, --help    Show this help message

Examples:
  cdx /tmp
  cdx -i /tmp
  up 2
  up 3/projects
USAGE
}

cdx_register_hook() {
  local type="$1" fn="$2"
  case "$type" in
    sync)  __CDX_HOOKS_SYNC+=("$fn") ;;
    async) __CDX_HOOKS_ASYNC+=("$fn") ;;
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
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      -h|--help) _cdx_usage; return 0 ;;
      --) shift; args+=("$@"); break ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local target="${args[1]:-${args[0]:-$HOME}}"
  local resolved_target=""

  if command -v zoxide &>/dev/null; then
    resolved_target="$(zoxide query -l -- "$target" 2>/dev/null | head -n 1)"
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

unalias up 2>/dev/null || true
up() {
  local inspect=0
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      -h|--help) _cdx_usage; return 0 ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local spec="${args[1]:-${args[0]:-}}"
  local count=1
  local subpath=""

  if [[ -n "$spec" ]]; then
    local num="${spec%%/*}"
    case "$num" in
      ''|*[!0-9]*) ;;
      *)
        count="$num"
        if [[ "$spec" == */* ]]; then
          subpath="${spec#*/}"
        fi
        ;;
    esac
  fi

  local target=""
  local i
  for ((i = 0; i < count; i++)); do
    target="../$target"
  done
  [[ -n "$subpath" ]] && target="${target}${subpath}"
  [[ -z "$target" ]] && target=".."

  if [[ $inspect -eq 1 ]]; then
    cdx -i "$target"
  else
    cdx "$target"
  fi
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
