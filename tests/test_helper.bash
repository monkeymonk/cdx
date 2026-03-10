# Resolve paths relative to this file, not the test file
__CDX_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDX_ROOT="$(cd "$__CDX_TEST_DIR/.." && pwd)"

load "$__CDX_TEST_DIR/test_helper/bats-support/load"
load "$__CDX_TEST_DIR/test_helper/bats-assert/load"

setup_cdx() {
  export CDX_CONFIG_DIR="$BATS_TMPDIR/cdx-config-$$"
  mkdir -p "$CDX_CONFIG_DIR/hooks"
  # Empty config by default — no hooks loaded
  echo 'CDX_HOOKS_ENABLED=()' > "$CDX_CONFIG_DIR/config.sh"
  # Reset hook arrays and load cdx
  unset __CDX_HOOKS_SYNC __CDX_HOOKS_ASYNC __CDX_RESOLVERS_CACHED __CDX_HOOK_CONTEXT
  source "$CDX_ROOT/cdx.sh"
  _cdx_init
}
