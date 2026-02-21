load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

CDX_ROOT="$BATS_TEST_DIRNAME/.."

setup_cdx() {
  export CDX_CONFIG_DIR="$BATS_TMPDIR/cdx-config-$$"
  mkdir -p "$CDX_CONFIG_DIR/hooks"
  # Empty config by default — no hooks loaded
  echo 'CDX_HOOKS_ENABLED=()' > "$CDX_CONFIG_DIR/config.sh"
  # Reset hook arrays and load cdx
  unset __CDX_HOOKS_SYNC __CDX_HOOKS_ASYNC
  source "$CDX_ROOT/cdx.sh"
}
