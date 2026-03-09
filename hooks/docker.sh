# cdx hook: docker — switch docker context on enter

cdx_hook_docker() {
  local mode="$1" dir="$2"
  [[ "$mode" = "enter" ]] || return 0  # enter only — avoid switching context in inspect mode
  local context_file="$dir/.docker-context"
  [[ -f "$context_file" ]] || return 0
  command -v docker &>/dev/null || return 0
  local context
  read -r context < "$context_file" || return 0
  [[ -n "$context" ]] || return 0
  docker context use "$context"
}

cdx_register_hook async cdx_hook_docker
