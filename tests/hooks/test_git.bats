#!/usr/bin/env bats
load '../../tests/test_helper'

setup() {
  setup_cdx
  source "$CDX_ROOT/hooks/git.sh"
  GITDIR="$(mktemp -d)"
  git init "$GITDIR" -q
}

teardown() {
  rm -rf "$GITDIR"
}

@test "git hook runs git status in a git repo" {
  run cdx_hook_git enter "$GITDIR"
  assert_success
}

@test "git hook silently skips non-git directories" {
  run cdx_hook_git enter /tmp
  assert_success
  assert_output ""
}

@test "git hook is registered as sync" {
  [[ " ${__CDX_HOOKS_SYNC[*]} " == *" cdx_hook_git "* ]]
}
