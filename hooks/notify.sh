# cdx hook: notify — send desktop notification on enter

cdx_hook_notify() {
  local mode="$1" dir="$2"
  [[ "$mode" = "enter" ]] || return 0
  command -v notify-send &>/dev/null || return 0
  notify-send "cdx" "Entered: $dir" --expire-time=2000 &>/dev/null
}

cdx_register_hook async cdx_hook_notify
