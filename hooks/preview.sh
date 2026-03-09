# cdx hook: preview — show directory contents on enter

# Cache ls command once at source time
if [[ -z "${__CDX_LS_CMD+set}" ]]; then
  if command -v eza &>/dev/null; then __CDX_LS_CMD=eza
  elif command -v exa &>/dev/null; then __CDX_LS_CMD=exa
  else __CDX_LS_CMD=ls
  fi
fi

cdx_hook_preview() {
  local mode="$1" dir="$2"
  # runs on both enter and inspect — intentional: inspect previews without navigating
  $__CDX_LS_CMD ${CDX_LS_ARGS:---color=auto} "$dir"
}

cdx_register_hook sync cdx_hook_preview
