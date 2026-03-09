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

@test "cdx calls sync hooks with mode and dir" {
  SYNC_HOOK_CALLED=""
  cdx_hook_testable() { SYNC_HOOK_CALLED="$1:$2"; }
  cdx_register_hook sync cdx_hook_testable
  cdx /tmp
  [ "$SYNC_HOOK_CALLED" = "enter:/tmp" ]
}

@test "cdx calls multiple sync hooks in order" {
  ORDER=""
  hook_a() { ORDER="${ORDER}a"; }
  hook_b() { ORDER="${ORDER}b"; }
  cdx_register_hook sync hook_a
  cdx_register_hook sync hook_b
  cdx /tmp
  [ "$ORDER" = "ab" ]
}

@test "cdx fires async hooks without blocking" {
  ASYNC_FILE="$BATS_TMPDIR/async_$$"
  cdx_hook_async_test() { sleep 0.1; touch "$1"; }
  cdx_register_hook async cdx_hook_async_test
  cdx "$BATS_TMPDIR"
  # should return immediately before async hook finishes
  [ ! -f "$ASYNC_FILE" ]
}

@test "cdx changes to target directory" {
  cdx /tmp
  [ "$(pwd)" = "/tmp" ]
}

@test "cdx with no args goes to HOME" {
  cdx /tmp
  cdx
  [ "$(pwd)" = "$HOME" ]
}

@test "cdx returns error for nonexistent directory" {
  run cdx /nonexistent_path_xyz
  assert_failure
  assert_output --partial "cdx: no such directory"
}

@test "cdx dispatches enter mode to hooks" {
  HOOK_MODE=""
  cdx_hook_mode_check() { HOOK_MODE="$1"; }
  cdx_register_hook sync cdx_hook_mode_check
  cdx /tmp
  [ "$HOOK_MODE" = "enter" ]
}

@test "cdx passes resolved absolute path to hooks" {
  HOOK_DIR=""
  cdx_hook_dir_check() { HOOK_DIR="$2"; }
  cdx_register_hook sync cdx_hook_dir_check
  cdx /tmp
  [ "$HOOK_DIR" = "/tmp" ]
}

@test "cdx -i does not change directory" {
  original="$(pwd)"
  cdx -i /tmp
  [ "$(pwd)" = "$original" ]
}

@test "cdx -i dispatches inspect mode to hooks" {
  HOOK_MODE=""
  cdx_hook_mode_check() { HOOK_MODE="$1"; }
  cdx_register_hook sync cdx_hook_mode_check
  cdx -i /tmp
  [ "$HOOK_MODE" = "inspect" ]
}

@test "cdx sources .cdxrc in target directory" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo 'CDXRC_LOADED=1' > "$tmpdir/.cdxrc"
  cdx "$tmpdir"
  [ "$CDXRC_LOADED" = "1" ]
  rm -rf "$tmpdir"
}

@test "cdx .cdxrc can override CDX_HOOKS_ENABLED" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo 'CDX_HOOKS_ENABLED=(extra)' > "$tmpdir/.cdxrc"
  cdx "$tmpdir"
  [[ " ${CDX_HOOKS_ENABLED[*]} " == *" extra "* ]]
  rm -rf "$tmpdir"
}

@test "cdx_register_hook deduplicates sync: calling twice registers once" {
  cdx_hook_dedup_sync() { :; }
  cdx_register_hook sync cdx_hook_dedup_sync
  cdx_register_hook sync cdx_hook_dedup_sync
  local count=0 fn
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    [[ "$fn" == "cdx_hook_dedup_sync" ]] && count=$(( count + 1 ))
  done
  [ "$count" -eq 1 ]
}

@test "cdx_register_hook deduplicates async: calling twice registers once" {
  cdx_hook_dedup_async() { :; }
  cdx_register_hook async cdx_hook_dedup_async
  cdx_register_hook async cdx_hook_dedup_async
  local count=0 fn
  for fn in "${__CDX_HOOKS_ASYNC[@]}"; do
    [[ "$fn" == "cdx_hook_dedup_async" ]] && count=$(( count + 1 ))
  done
  [ "$count" -eq 1 ]
}

@test "CDX_HOOKS_ENABLED with duplicate entry registers hook only once" {
  echo 'CDX_HOOKS_ENABLED=(myhook myhook)' > "$CDX_CONFIG_DIR/config.sh"
  cat > "$CDX_CONFIG_DIR/hooks/myhook.sh" <<'EOF'
cdx_hook_myhook() { :; }
cdx_register_hook sync cdx_hook_myhook
EOF
  _cdx_init
  local count=0 fn
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    [[ "$fn" == "cdx_hook_myhook" ]] && count=$(( count + 1 ))
  done
  [ "$count" -eq 1 ]
}
