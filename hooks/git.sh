# cdx hook: git — show git status on enter

cdx_hook_git() {
  local mode="$1" dir="$2"
  # runs on both enter and inspect — intentional: inspect shows status without navigating
  [[ -d "$dir/.git" ]] || return 0
  command -v git &>/dev/null || return 0
  git -C "$dir" status -sb
}

cdx_register_hook sync cdx_hook_git
