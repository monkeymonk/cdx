#!/usr/bin/env bash
set -euo pipefail

CDX_REPO="https://raw.githubusercontent.com/monkeymonk/cdx"
CDX_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/cdx"
CDX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cdx"
CDX_TAG=""

_detect_shell_rc() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
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

_patch_rc() {
  local rc="$1"
  local line="source \"$CDX_DATA/cdx.sh\""
  if grep -qF "$line" "$rc" 2>/dev/null; then
    echo "cdx: already sourced in $rc"
  else
    echo "" >> "$rc"
    echo "# cdx — extensible cd wrapper" >> "$rc"
    echo "$line" >> "$rc"
    echo "cdx: added source line to $rc"
  fi
}

echo "Installing cdx..."

mkdir -p "$CDX_DATA"
mkdir -p "$CDX_CONFIG/hooks"

CDX_TAG="$(_latest_tag || true)"
if [[ -n "$CDX_TAG" ]]; then
  CDX_BASE="$CDX_REPO/$CDX_TAG"
  echo "cdx: using latest tag $CDX_TAG"
else
  CDX_BASE="$CDX_REPO/main"
  echo "cdx: could not determine latest tag, using main"
fi

_download "$CDX_BASE/cdx.sh" "$CDX_DATA/cdx.sh"

for hook in preview git notify docker; do
  _download "$CDX_BASE/hooks/${hook}.sh" "$CDX_CONFIG/hooks/${hook}.sh"
done

if [[ ! -f "$CDX_CONFIG/config.sh" ]]; then
  cat > "$CDX_CONFIG/config.sh" <<'CONFIG'
# cdx config — edit to enable/disable hooks
# Add custom hooks to ~/.config/cdx/hooks/ and list them here
CDX_HOOKS_ENABLED=(preview git)
CONFIG
  echo "cdx: created $CDX_CONFIG/config.sh"
else
  echo "cdx: $CDX_CONFIG/config.sh already exists, skipping"
fi

SHELL_RC="$(_detect_shell_rc)"
FPATH_FIRST=""
if [[ -n "${FPATH+x}" ]]; then
  FPATH_FIRST="${FPATH%%:*}"
fi
if [[ "$SHELL_RC" == *zshrc* ]] && [[ -n "$FPATH_FIRST" ]] && [[ -d "$FPATH_FIRST" ]]; then
  _download "$CDX_BASE/completions/cdx.zsh" "$FPATH_FIRST/_cdx"
elif [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
  _download "$CDX_BASE/completions/cdx.bash" \
    "$HOME/.local/share/bash-completion/completions/cdx"
fi

_patch_rc "$SHELL_RC"

echo ""
echo "cdx installed."
echo "Restart your shell or run: source $SHELL_RC"
echo ""
echo "To use cdx as cd: add 'alias cd=cdx' to $CDX_CONFIG/config.sh"
