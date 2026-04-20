#!/usr/bin/env bash
set -euo pipefail

CDX_REPO="https://raw.githubusercontent.com/monkeymonk/cdx"
CDX_BIN="${HOME}/.local/bin"
CDX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cdx"
CDX_TAG=""

_detect_shell_kind() {
  # Allow explicit override: CDX_INSTALL_SHELL=fish bash install.sh
  if [[ -n "${CDX_INSTALL_SHELL:-}" ]]; then
    echo "$CDX_INSTALL_SHELL"
    return
  fi
  if [[ -n "${FISH_VERSION:-}" ]] || [[ "$SHELL" == */fish ]]; then
    echo "fish"
  elif [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    echo "zsh"
  else
    echo "bash"
  fi
}

_detect_shell_rc() {
  case "$(_detect_shell_kind)" in
    fish) echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
    zsh)  echo "$HOME/.zshrc" ;;
    *)    echo "$HOME/.bashrc" ;;
  esac
}

_download() {
  local url="$1" dest="$2"
  if [[ "$url" == https://raw.githubusercontent.com/* ]] && [[ "$url" != *\?* ]]; then
    url="${url}?ts=$(date +%s)"
  fi
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url"
  else
    echo "cdx install: curl or wget required" >&2
    exit 1
  fi
}

_latest_tag() {
  local api="https://api.github.com/repos/monkeymonk/cdx/tags?per_page=1"
  local raw
  if command -v curl &>/dev/null; then
    raw="$(curl -fsSL "$api")"
  elif command -v wget &>/dev/null; then
    raw="$(wget -qO - "$api")"
  else
    return 1
  fi
  if command -v jq &>/dev/null; then
    printf '%s' "$raw" | jq -r '.[0].name // empty'
  else
    printf '%s' "$raw" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]\+\)".*/\1/p' | head -n1
  fi
}

_confirm() {
  local prompt="$1"
  local reply
  printf '%s [y/N] ' "$prompt" >&2
  read -r reply </dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

_patch_rc() {
  local rc="$1" kind="$2"
  local new_line legacy_line
  if [[ "$kind" == "fish" ]]; then
    new_line="source \"$HOME/.local/bin/cdx.fish\""
    legacy_line=""
    mkdir -p "$(dirname "$rc")"
    [[ -f "$rc" ]] || : > "$rc"
  else
    new_line="source \"$HOME/.local/bin/cdx.sh\""
    legacy_line="source \"${XDG_DATA_HOME:-$HOME/.local/share}/cdx/cdx.sh\""
  fi

  # Migrate legacy source line if present
  if [[ -n "$legacy_line" ]] && grep -qF "$legacy_line" "$rc" 2>/dev/null; then
    if _confirm "cdx: migrate old source line in $rc?"; then
      sed -i "s|$legacy_line|$new_line|" "$rc"
      echo "cdx: updated source line in $rc (migrated from old path)"
    else
      echo "cdx: skipped migration of $rc"
    fi
    return
  fi

  if grep -qF "$new_line" "$rc" 2>/dev/null; then
    echo "cdx: already sourced in $rc"
  else
    if _confirm "cdx: append source line to $rc?"; then
      printf '\n# cdx — extensible cd wrapper\n%s\n' "$new_line" >> "$rc"
      echo "cdx: added source line to $rc"
    else
      echo "cdx: skipped $rc — add manually: $new_line"
    fi
  fi
}

echo "Installing cdx..."

mkdir -p "$CDX_BIN"
mkdir -p "$CDX_CONFIG/hooks"

CDX_TAG="$(_latest_tag || true)"
if [[ -n "$CDX_TAG" ]]; then
  CDX_BASE="$CDX_REPO/$CDX_TAG"
  echo "cdx: using latest tag $CDX_TAG"
else
  CDX_BASE="$CDX_REPO/main"
  echo "cdx: could not determine latest tag, using main"
fi

SHELL_KIND="$(_detect_shell_kind)"
SHELL_RC="$(_detect_shell_rc)"
echo "cdx: detected shell: $SHELL_KIND"

if [[ "$SHELL_KIND" == "fish" ]]; then
  HOOK_EXT="fish"
  CORE_FILE="cdx.fish"
  CONFIG_FILE="config.fish"
else
  HOOK_EXT="sh"
  CORE_FILE="cdx.sh"
  CONFIG_FILE="config.sh"
fi

_download "$CDX_BASE/$CORE_FILE" "$CDX_BIN/$CORE_FILE"

for hook in preview git notify docker; do
  _download "$CDX_BASE/hooks/${hook}.${HOOK_EXT}" "$CDX_CONFIG/hooks/${hook}.${HOOK_EXT}"
done

_default_config_posix() {
  cat <<'CONFIG'
# cdx config — edit to enable/disable hooks
# Add custom hooks to ~/.config/cdx/hooks/ and list them here
CDX_HOOKS_ENABLED=(preview git)
CONFIG
}

_default_config_fish() {
  cat <<'CONFIG'
# cdx config — edit to enable/disable hooks
# Add custom hooks to ~/.config/cdx/hooks/ and list them here
set -g CDX_HOOKS_ENABLED preview git
CONFIG
}

_write_default_config() {
  if [[ "$SHELL_KIND" == "fish" ]]; then
    _default_config_fish > "$1"
  else
    _default_config_posix > "$1"
  fi
}

CONFIG_PATH="$CDX_CONFIG/$CONFIG_FILE"
if [[ ! -f "$CONFIG_PATH" ]]; then
  _write_default_config "$CONFIG_PATH"
  echo "cdx: created $CONFIG_PATH"
else
  if _confirm "cdx: $CONFIG_PATH already exists, overwrite?"; then
    _write_default_config "$CONFIG_PATH"
    echo "cdx: replaced $CONFIG_PATH"
  else
    echo "cdx: kept existing $CONFIG_PATH"
  fi
fi

# Install completions
mkdir -p "$CDX_BIN/completions"
if [[ "$SHELL_KIND" == "fish" ]]; then
  # Fish autoloads from ~/.config/fish/completions/
  FISH_COMP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
  mkdir -p "$FISH_COMP_DIR"
  _download "$CDX_BASE/completions/cdx.fish" "$FISH_COMP_DIR/cdx.fish"
  # Also keep a copy alongside cdx.fish so the source line picks it up.
  cp "$FISH_COMP_DIR/cdx.fish" "$CDX_BIN/completions/cdx.fish"
else
  _download "$CDX_BASE/completions/cdx.zsh" "$CDX_BIN/completions/cdx.zsh"
  _download "$CDX_BASE/completions/cdx.bash" "$CDX_BIN/completions/cdx.bash"
  if [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
    cp "$CDX_BIN/completions/cdx.bash" \
      "$HOME/.local/share/bash-completion/completions/cdx"
  fi
fi

_patch_rc "$SHELL_RC" "$SHELL_KIND"

echo ""
echo "cdx installed."
if [[ "$SHELL_KIND" == "fish" ]]; then
  echo "Restart your shell or run: source $SHELL_RC"
  echo ""
  echo "To use cdx as cd: add 'alias cd cdx' to $CONFIG_PATH"
else
  echo "Restart your shell or run: source $SHELL_RC"
  echo ""
  echo "To use cdx as cd: add 'alias cd=cdx' to $CONFIG_PATH"
fi
