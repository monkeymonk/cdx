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

@test "cdx --up goes one level up" {
  cdx --up
  [ "$(pwd)" = "/tmp/a/b" ]
}

@test "cdx --up N goes N levels up" {
  cdx --up 3
  [ "$(pwd)" = "/tmp" ]
}

@test "cdx --up N/subpath goes N levels up then into subpath" {
  cdx --up 2/b
  [ "$(pwd)" = "/tmp/a/b" ]
}

@test "cdx -i --up does not change directory" {
  original="$(pwd)"
  cdx -i --up 2
  [ "$(pwd)" = "$original" ]
}

@test "cdx -i --up dispatches inspect mode" {
  HOOK_MODE=""
  cdx_hook_mode_check() { HOOK_MODE="$1"; }
  cdx_register_hook sync cdx_hook_mode_check all
  cdx -i --up 1
  [ "$HOOK_MODE" = "inspect" ]
}

@test "cdx -N shorthand goes N levels up" {
  cdx -3
  [ "$(pwd)" = "/tmp" ]
}

@test "cdx -1 shorthand goes one level up" {
  cdx -1
  [ "$(pwd)" = "/tmp/a/b" ]
}

@test "cdx -N/subpath shorthand goes N levels up then into subpath" {
  cdx -2/b
  [ "$(pwd)" = "/tmp/a/b" ]
}

@test "cdx -i -N shorthand does not change directory" {
  original="$(pwd)"
  cdx -i -2
  [ "$(pwd)" = "$original" ]
}

@test "cdx --up with invalid spec returns error" {
  run cdx --up foo
  assert_failure
  assert_output --partial "cdx: invalid --up spec: foo"
}

@test "cdx -0 returns error" {
  run cdx -0
  assert_failure
  assert_output --partial "cdx: invalid --up spec: 0"
}
