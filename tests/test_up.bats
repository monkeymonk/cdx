#!/usr/bin/env bats
load '../tests/test_helper'

setup() {
  setup_cdx
  builtin cd /tmp
  mkdir -p /tmp/a/b/c
  builtin cd /tmp/a/b/c
}

teardown() {
  rm -rf /tmp/a
}

@test "up goes one level up" {
  up
  [ "$(pwd)" = "/tmp/a/b" ]
}

@test "up N goes N levels up" {
  up 3
  [ "$(pwd)" = "/tmp" ]
}

@test "up N/subpath goes N levels up then into subpath" {
  up 2/a
  [ "$(pwd)" = "/tmp/a" ]
}

@test "up -i does not change directory" {
  original="$(pwd)"
  up -i 2
  [ "$(pwd)" = "$original" ]
}

@test "up -i dispatches inspect mode" {
  HOOK_MODE=""
  cdx_hook_mode_check() { HOOK_MODE="$1"; }
  cdx_register_hook sync cdx_hook_mode_check
  up -i 1
  [ "$HOOK_MODE" = "inspect" ]
}
