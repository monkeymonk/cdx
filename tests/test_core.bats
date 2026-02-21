#!/usr/bin/env bats
load '../tests/test_helper'

setup() { setup_cdx; }

@test "cdx_register_hook adds sync hook to __CDX_HOOKS_SYNC" {
  cdx_register_hook sync my_hook_fn
  [[ " ${__CDX_HOOKS_SYNC[*]} " == *" my_hook_fn "* ]]
}

@test "cdx_register_hook adds async hook to __CDX_HOOKS_ASYNC" {
  cdx_register_hook async my_hook_fn
  [[ " ${__CDX_HOOKS_ASYNC[*]} " == *" my_hook_fn "* ]]
}

@test "cdx_register_hook with unknown type prints warning to stderr" {
  run cdx_register_hook bad my_hook_fn
  assert_output --partial "cdx: unknown hook type: bad"
}

@test "_cdx_init sources config.sh from CDX_CONFIG_DIR" {
  echo 'CDX_HOOKS_ENABLED=(myhook)' > "$CDX_CONFIG_DIR/config.sh"
  cat > "$CDX_CONFIG_DIR/hooks/myhook.sh" <<'EOF'
cdx_hook_myhook() { :; }
cdx_register_hook sync cdx_hook_myhook
EOF
  _cdx_init
  [[ " ${__CDX_HOOKS_SYNC[*]} " == *" cdx_hook_myhook "* ]]
}

@test "_cdx_init warns when hook file not found" {
  echo 'CDX_HOOKS_ENABLED=(missing)' > "$CDX_CONFIG_DIR/config.sh"
  run _cdx_init
  assert_output --partial "cdx: hook not found: missing"
}

@test "_cdx_init with empty CDX_HOOKS_ENABLED loads no hooks" {
  echo 'CDX_HOOKS_ENABLED=()' > "$CDX_CONFIG_DIR/config.sh"
  _cdx_init
  [ ${#__CDX_HOOKS_SYNC[@]} -eq 0 ]
  [ ${#__CDX_HOOKS_ASYNC[@]} -eq 0 ]
}
