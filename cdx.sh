#!/usr/bin/env bash
# cdx — extensible cd wrapper

__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()
__CDX_RESOLVER_ORDER=(zoxide zshz z zlua autojump)
__CDX_RESOLVERS_CACHED=()
__CDX_VERSION="0.2.7"

# Per-hook shell context: interactive (default), noninteractive, all
unset __CDX_HOOK_CONTEXT 2>/dev/null
declare -gA __CDX_HOOK_CONTEXT 2>/dev/null || typeset -gA __CDX_HOOK_CONTEXT 2>/dev/null || true

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
  local type="$1" fn="$2" ctx="${3:-interactive}"
  case "$ctx" in
    interactive|noninteractive|all) ;;
    *) echo "cdx: unknown hook context: $ctx (use interactive, noninteractive, or all)" >&2; return 1 ;;
  esac
  case "$type" in
    sync)
      [[ " ${__CDX_HOOKS_SYNC[*]} " == *" $fn "* ]] && return 0
      __CDX_HOOKS_SYNC+=("$fn") ;;
    async)
      [[ " ${__CDX_HOOKS_ASYNC[*]} " == *" $fn "* ]] && return 0
      __CDX_HOOKS_ASYNC+=("$fn") ;;
    *)     echo "cdx: unknown hook type: $type" >&2; return 1 ;;
  esac
  __CDX_HOOK_CONTEXT[$fn]="$ctx"
}

# --- Directory resolvers ---

_cdx_resolver_zoxide() {
  command -v zoxide &>/dev/null || return 1
  zoxide query -- "$1" 2>/dev/null
}

_cdx_resolver_zshz() {
  declare -f zshz &>/dev/null || return 1
  zshz -e "$1" 2>/dev/null
}

_cdx_resolver_z() {
  declare -f _z &>/dev/null || return 1
  _z -e "$1" 2>&1
}

_cdx_resolver_zlua() {
  declare -f _zlua &>/dev/null || return 1
  _zlua -e "$1" 2>/dev/null
}

_cdx_resolver_autojump() {
  command -v autojump &>/dev/null || return 1
  local result
  result="$(autojump "$1" 2>/dev/null)" || return 1
  [[ -d "$result" ]] && echo "$result" || return 1
}

_cdx_cache_resolvers() {
  __CDX_RESOLVERS_CACHED=()
  if [[ -n "${CDX_RESOLVERS+set}" ]]; then
    __CDX_RESOLVERS_CACHED=("${CDX_RESOLVERS[@]}")
  else
    local name
    for name in "${__CDX_RESOLVER_ORDER[@]}"; do
      typeset -f "_cdx_resolver_${name}" &>/dev/null && __CDX_RESOLVERS_CACHED+=("$name")
    done
  fi
}

_cdx_resolve() {
  local query="$1"
  local name result

  # Re-cache if CDX_RESOLVERS was set/changed or cache is empty
  if [[ -n "${CDX_RESOLVERS+set}" ]] || [[ ${#__CDX_RESOLVERS_CACHED[@]} -eq 0 ]]; then
    _cdx_cache_resolvers
  fi

  for name in "${__CDX_RESOLVERS_CACHED[@]}"; do
    if result="$("_cdx_resolver_${name}" "$query")" && [[ -n "$result" ]]; then
      echo "$result"
      return 0
    fi
  done
  return 1
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
      -*)
        # Unified numeric-flag detection (works in both bash and zsh)
        case "${1#-}" in
          [0-9]*) up_mode=1; up_spec="${1#-}" ;;
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

  if [[ ! -d "$target" ]]; then
    resolved_target="$(_cdx_resolve "$target")" || true
  fi
  [[ -z "$resolved_target" ]] && resolved_target="$target"

  local resolved mode
  if [[ $inspect -eq 1 ]]; then
    mode="inspect"
    resolved="$(builtin cd "$resolved_target" 2>/dev/null && pwd)" || {
      echo "cdx: no such directory: $target" >&2
      return 1
    }
    echo "$resolved"
  else
    mode="enter"
    builtin cd "$resolved_target" 2>/dev/null || {
      echo "cdx: no such directory: $target" >&2
      return 1
    }
    resolved="$PWD"
  fi

  if [[ "${CDX_CDXRC:-1}" != "0" ]]; then
    local cdxrc="$resolved/.cdxrc"
    [[ -f "$cdxrc" ]] && source "$cdxrc"
  fi

  # Determine shell context for hook filtering
  local _cdx_shell_ctx="noninteractive"
  [[ -o interactive ]] 2>/dev/null && _cdx_shell_ctx="interactive"

  # Dispatch hooks whose context matches the current shell
  local fn _ctx
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    _ctx="${__CDX_HOOK_CONTEXT[$fn]:-interactive}"
    [[ "$_ctx" == "$_cdx_shell_ctx" || "$_ctx" == "all" ]] || continue
    typeset -f "$fn" &>/dev/null && "$fn" "$mode" "$resolved"
  done
  for fn in "${__CDX_HOOKS_ASYNC[@]}"; do
    _ctx="${__CDX_HOOK_CONTEXT[$fn]:-interactive}"
    [[ "$_ctx" == "$_cdx_shell_ctx" || "$_ctx" == "all" ]] || continue
    typeset -f "$fn" &>/dev/null && ("$fn" "$mode" "$resolved" &>/dev/null) &
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

  _cdx_cache_resolvers
}

if [[ -o interactive ]] 2>/dev/null; then
  _cdx_init
fi

# Register zsh completions when sourced in an interactive zsh session
if [[ -n "${ZSH_VERSION:-}" ]] && [[ -o interactive ]]; then
  # Capture script directory at source time (zsh-only prompt expansion)
  __CDX_SCRIPT_DIR="${${(%):-%x}:h}"
  _cdx_setup_completions() {
    local comp_file=""
    # Check next to the script first
    [[ -f "$__CDX_SCRIPT_DIR/completions/cdx.zsh" ]] && comp_file="$__CDX_SCRIPT_DIR/completions/cdx.zsh"
    # Fallback: check fpath for _cdx
    if [[ -z "$comp_file" ]]; then
      local dir
      for dir in $fpath; do
        [[ -f "$dir/_cdx" ]] && { comp_file="$dir/_cdx"; break; }
      done
    fi
    if [[ -n "$comp_file" ]]; then
      source "$comp_file"
    fi
    compdef _cdx cdx 2>/dev/null
    # Also register for cd if aliased to cdx
    if [[ "$(alias cd 2>/dev/null)" == *cdx* ]]; then
      compdef _cdx cd 2>/dev/null
    fi
  }
  _cdx_setup_completions
  unset -f _cdx_setup_completions
  unset __CDX_SCRIPT_DIR
fi
