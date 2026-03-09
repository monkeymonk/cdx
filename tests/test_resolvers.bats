#!/usr/bin/env bats
load '../tests/test_helper'

setup() { setup_cdx; }

# --- _cdx_resolve uses first available resolver ---

@test "_cdx_resolve returns resolved path from first matching resolver" {
  _cdx_resolver_fake() { echo "/resolved/path"; return 0; }
  CDX_RESOLVERS=(fake)
  run _cdx_resolve "myquery"
  assert_success
  assert_output "/resolved/path"
}

@test "_cdx_resolve skips resolver that fails and tries next" {
  _cdx_resolver_first() { return 1; }
  _cdx_resolver_second() { echo "/from/second"; return 0; }
  CDX_RESOLVERS=(first second)
  run _cdx_resolve "myquery"
  assert_success
  assert_output "/from/second"
}

@test "_cdx_resolve returns failure when no resolver matches" {
  _cdx_resolver_nope() { return 1; }
  CDX_RESOLVERS=(nope)
  run _cdx_resolve "myquery"
  assert_failure
  assert_output ""
}

@test "_cdx_resolve returns failure when CDX_RESOLVERS is empty" {
  CDX_RESOLVERS=()
  run _cdx_resolve "myquery"
  assert_failure
  assert_output ""
}

# --- Auto-detect: no CDX_RESOLVERS set ---

@test "_cdx_resolve auto-detects available resolvers when CDX_RESOLVERS unset" {
  unset CDX_RESOLVERS
  # Override the zoxide resolver to avoid needing real zoxide
  _cdx_resolver_zoxide() { echo "/auto/detected"; return 0; }
  run _cdx_resolve "myquery"
  assert_success
  assert_output "/auto/detected"
}

# --- CDX_RESOLVERS overrides auto-detect ---

@test "_cdx_resolve uses CDX_RESOLVERS order over default when set" {
  _cdx_resolver_custom() { echo "/custom"; return 0; }
  CDX_RESOLVERS=(custom)
  run _cdx_resolve "myquery"
  assert_success
  assert_output "/custom"
}

# --- Integration: cdx uses resolver for non-directory target ---

@test "cdx uses resolver when target is not a directory" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  _cdx_resolver_stub() { echo "$tmpdir"; return 0; }
  CDX_RESOLVERS=(stub)
  cdx "nonexistent_keyword"
  [ "$(pwd)" = "$tmpdir" ]
  rm -rf "$tmpdir"
}

@test "cdx does not call resolver when target is a valid directory" {
  RESOLVER_CALLED=0
  _cdx_resolver_spy() { RESOLVER_CALLED=1; echo "/tmp"; return 0; }
  CDX_RESOLVERS=(spy)
  cdx /tmp
  [ "$RESOLVER_CALLED" -eq 0 ]
}

# --- Built-in resolver functions exist ---

@test "_cdx_resolver_zoxide is a defined function" {
  declare -F _cdx_resolver_zoxide
}

@test "_cdx_resolver_zshz is a defined function" {
  declare -F _cdx_resolver_zshz
}

@test "_cdx_resolver_z is a defined function" {
  declare -F _cdx_resolver_z
}

@test "_cdx_resolver_autojump is a defined function" {
  declare -F _cdx_resolver_autojump
}

@test "_cdx_resolver_zlua is a defined function" {
  declare -F _cdx_resolver_zlua
}

# --- Default resolver order ---

@test "__CDX_RESOLVER_ORDER contains expected resolvers" {
  [[ " ${__CDX_RESOLVER_ORDER[*]} " == *" zoxide "* ]]
  [[ " ${__CDX_RESOLVER_ORDER[*]} " == *" zshz "* ]]
  [[ " ${__CDX_RESOLVER_ORDER[*]} " == *" z "* ]]
  [[ " ${__CDX_RESOLVER_ORDER[*]} " == *" zlua "* ]]
  [[ " ${__CDX_RESOLVER_ORDER[*]} " == *" autojump "* ]]
}
