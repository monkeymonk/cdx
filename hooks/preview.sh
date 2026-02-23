# cdx hook: preview — show directory contents on enter

cdx_hook_preview() {
  local mode="$1" dir="$2"
  # runs on both enter and inspect — intentional: inspect previews without navigating
  if command -v eza &>/dev/null; then
    eza ${CDX_LS_ARGS:---color=auto} "$dir"
  elif command -v exa &>/dev/null; then
    exa ${CDX_LS_ARGS:---color=auto} "$dir"
  else
    ls ${CDX_LS_ARGS:--lh} "$dir"
  fi
}

cdx_register_hook sync cdx_hook_preview
