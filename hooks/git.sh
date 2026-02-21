# cdx hook: git — show git status on enter

cdx_hook_git() {
  local mode="$1" dir="$2"
  [[ -d "$dir/.git" ]] || return 0
  command -v git &>/dev/null || return 0
  git -C "$dir" status -sb
}

cdx_register_hook sync cdx_hook_git
