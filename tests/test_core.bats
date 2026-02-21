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
