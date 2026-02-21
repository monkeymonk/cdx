#!/usr/bin/env bash
# cdx — extensible cd wrapper

__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()

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
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      --) shift; args+=("$@"); break ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local target="${args[0]:-$HOME}"

  local resolved
  resolved="$(builtin cd "$target" 2>/dev/null && pwd)" || {
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

up() {
  local inspect=0
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local spec="${args[0]:-}"
  local count=1
  local subpath=""

  if [[ -n "$spec" ]]; then
    if [[ "$spec" =~ ^([0-9]+)(/(.*))?$ ]]; then
      count="${BASH_REMATCH[1]}"
      subpath="${BASH_REMATCH[3]:-}"
    fi
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
