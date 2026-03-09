#!/usr/bin/env bats
load '../test_helper'

setup() {
  setup_cdx
  source "$CDX_ROOT/hooks/preview.sh"
}

@test "preview hook runs on enter mode" {
  run cdx_hook_preview enter /tmp
  assert_success
}

@test "preview hook does not error on inspect mode" {
  run cdx_hook_preview inspect /tmp
  assert_success
}

@test "preview hook is registered as sync" {
  [[ " ${__CDX_HOOKS_SYNC[*]} " == *" cdx_hook_preview "* ]]
}
