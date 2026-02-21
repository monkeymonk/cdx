#!/usr/bin/env bats
load '../../tests/test_helper'

setup() {
  setup_cdx
  source "$CDX_ROOT/hooks/docker.sh"
  TESTDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "docker hook silently skips when no .docker-context file" {
  run cdx_hook_docker enter /tmp
  assert_success
  assert_output ""
}

@test "docker hook reads context from .docker-context file" {
  echo "my-context" > "$TESTDIR/.docker-context"
  docker() { echo "docker context use: $*"; }
  export -f docker
  run cdx_hook_docker enter "$TESTDIR"
  assert_output --partial "my-context"
}

@test "docker hook is registered as async" {
  [[ " ${__CDX_HOOKS_ASYNC[*]} " == *" cdx_hook_docker "* ]]
}
