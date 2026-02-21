# cdx Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build `cdx`, an extensible shell navigation tool that wraps `cd` with a lifecycle hook system.

**Architecture:** Single core engine (`cdx.sh`) exposes a `cdx` shell function and an `up` helper. On each navigation, it dispatches registered sync and async hooks. Hooks are loaded at shell startup from `~/.config/cdx/hooks/` based on `CDX_HOOKS_ENABLED` in `~/.config/cdx/config.sh`.

**Tech Stack:** Bash/Zsh shell scripting, bats-core for testing.

---

## Task 1: Project scaffold

**Files:**
- Create: `cdx.sh`
- Create: `hooks/preview.sh`, `hooks/git.sh`, `hooks/notify.sh`, `hooks/docker.sh` (empty)
- Create: `completions/cdx.bash`, `completions/cdx.zsh` (empty)
- Create: `install.sh` (empty)
- Create: `tests/test_helper.bash`
- Create: `tests/test_core.bats`
- Create: `tests/test_up.bats`
- Create: `tests/hooks/test_preview.bats`, `tests/hooks/test_git.bats`

**Step 1: Create directory structure**

```bash
mkdir -p hooks completions tests/hooks
```

**Step 2: Add bats-core as git submodule**

```bash
git submodule add https://github.com/bats-core/bats-core.git tests/bats
git submodule add https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
```

**Step 3: Create test helper**

`tests/test_helper.bash`:
```bash
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
```

**Step 4: Create empty `cdx.sh`**

```bash
#!/usr/bin/env bash
# cdx — extensible cd wrapper
```

**Step 5: Create empty hook stubs**

Each `hooks/*.sh` file gets a one-line comment:
```bash
# cdx hook: <name>
```

**Step 6: Verify bats runs**

```bash
./tests/bats/bin/bats tests/
```
Expected: `0 tests, 0 failures`

**Step 7: Commit**

```bash
git add .
git commit -m "chore: project scaffold with bats test harness"
```

---

## Task 2: Core — hook registry

**Files:**
- Modify: `cdx.sh`
- Test: `tests/test_core.bats`

**Step 1: Write failing tests**

`tests/test_core.bats`:
```bash
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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: FAIL — `cdx_register_hook: command not found`

**Step 3: Implement hook registry in `cdx.sh`**

```bash
__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()

cdx_register_hook() {
  local type="$1" fn="$2"
  case "$type" in
    sync)  __CDX_HOOKS_SYNC+=("$fn") ;;
    async) __CDX_HOOKS_ASYNC+=("$fn") ;;
    *)     echo "cdx: unknown hook type: $type" >&2; return 1 ;;
  esac
}
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add cdx.sh tests/test_core.bats
git commit -m "feat: hook registry (cdx_register_hook)"
```

---

## Task 3: Core — config and hook loading

**Files:**
- Modify: `cdx.sh`
- Test: `tests/test_core.bats`

**Step 1: Write failing tests**

Append to `tests/test_core.bats`:
```bash
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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: FAIL — `_cdx_init: command not found`

**Step 3: Implement `_cdx_init` in `cdx.sh`**

```bash
_cdx_init() {
  local config_dir="${CDX_CONFIG_DIR:-$HOME/.config/cdx}"
  local config="$config_dir/config.sh"
  [[ -f "$config" ]] && source "$config"

  local hooks_dir="$config_dir/hooks"
  local name
  for name in "${CDX_HOOKS_ENABLED[@]}"; do
    local hook_file="$hooks_dir/${name}.sh"
    if [[ -f "$hook_file" ]]; then
      source "$hook_file"
    else
      echo "cdx: hook not found: $name" >&2
    fi
  done
}

_cdx_init
```

Note: `_cdx_init` is called at the bottom of `cdx.sh` so hooks load when the file is sourced.

**Step 4: Update `setup_cdx` in test helper to reset init state**

In `tests/test_helper.bash`, update `setup_cdx` to unset `_cdx_init`'s side effects by re-sourcing cleanly. The current implementation already resets arrays before sourcing, which re-runs `_cdx_init` — this is correct.

**Step 5: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: all tests pass

**Step 6: Commit**

```bash
git add cdx.sh tests/test_core.bats tests/test_helper.bash
git commit -m "feat: config and hook loading (_cdx_init)"
```

---

## Task 4: Core — hook dispatch

**Files:**
- Modify: `cdx.sh`
- Test: `tests/test_core.bats`

**Step 1: Write failing tests**

Append to `tests/test_core.bats`:
```bash
@test "_cdx_dispatch calls sync hooks with mode and dir" {
  SYNC_HOOK_CALLED=""
  cdx_hook_testable() { SYNC_HOOK_CALLED="$1:$2"; }
  cdx_register_hook sync cdx_hook_testable
  _cdx_dispatch enter /tmp
  [ "$SYNC_HOOK_CALLED" = "enter:/tmp" ]
}

@test "_cdx_dispatch calls multiple sync hooks in order" {
  ORDER=""
  hook_a() { ORDER="${ORDER}a"; }
  hook_b() { ORDER="${ORDER}b"; }
  cdx_register_hook sync hook_a
  cdx_register_hook sync hook_b
  _cdx_dispatch enter /tmp
  [ "$ORDER" = "ab" ]
}

@test "_cdx_dispatch fires async hooks without blocking" {
  ASYNC_FILE="$BATS_TMPDIR/async_$$"
  cdx_hook_async_test() { sleep 0.1; touch "$1"; }
  cdx_register_hook async cdx_hook_async_test
  _cdx_dispatch enter "$ASYNC_FILE"
  # should return immediately before async hook finishes
  [ ! -f "$ASYNC_FILE" ]
}
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: FAIL — `_cdx_dispatch: command not found`

**Step 3: Implement `_cdx_dispatch` in `cdx.sh`**

Add before `_cdx_init`:
```bash
_cdx_dispatch() {
  local mode="$1" dir="$2"
  local fn
  for fn in "${__CDX_HOOKS_SYNC[@]}"; do
    "$fn" "$mode" "$dir"
  done
  for fn in "${__CDX_HOOKS_ASYNC[@]}"; do
    ("$fn" "$mode" "$dir" &>/dev/null) &
  done
}
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: all tests pass

**Step 5: Commit**

```bash
git add cdx.sh tests/test_core.bats
git commit -m "feat: hook dispatch (_cdx_dispatch)"
```

---

## Task 5: Core — `cdx` function

**Files:**
- Modify: `cdx.sh`
- Test: `tests/test_core.bats`

**Step 1: Write failing tests**

Append to `tests/test_core.bats`:
```bash
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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: FAIL — `cdx: command not found`

**Step 3: Implement `cdx` function in `cdx.sh`**

Add before `_cdx_init`:
```bash
cdx() {
  local inspect=0
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      --) shift; args+=("$@"); break ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local target="${args[0]:-$HOME}"

  local resolved
  resolved="$(builtin cd "$target" 2>/dev/null && pwd)" || {
    echo "cdx: no such directory: $target" >&2
    return 1
  }

  local mode="enter"
  if [[ $inspect -eq 1 ]]; then
    mode="inspect"
  else
    builtin cd "$resolved" || return 1
  fi

  local cdxrc="$resolved/.cdxrc"
  [[ -f "$cdxrc" ]] && source "$cdxrc"

  _cdx_dispatch "$mode" "$resolved"
}
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: all tests pass

**Step 5: Commit**

```bash
git add cdx.sh tests/test_core.bats
git commit -m "feat: cdx function (cd override with hook dispatch)"
```

---

## Task 6: Core — inspect mode and `.cdxrc`

**Files:**
- Modify: `cdx.sh` (already implemented above — tests only)
- Test: `tests/test_core.bats`

**Step 1: Write failing tests**

Append to `tests/test_core.bats`:
```bash
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
```

**Step 2: Run tests to verify they pass (already implemented in Task 5)**

```bash
./tests/bats/bin/bats tests/test_core.bats
```
Expected: all tests pass

**Step 3: Commit**

```bash
git add tests/test_core.bats
git commit -m "test: inspect mode and .cdxrc coverage"
```

---

## Task 7: `up` command

**Files:**
- Modify: `cdx.sh`
- Test: `tests/test_up.bats`

**Step 1: Write failing tests**

`tests/test_up.bats`:
```bash
load '../tests/test_helper'

setup() {
  setup_cdx
  # go somewhere deep enough to test up
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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/test_up.bats
```
Expected: FAIL — `up: command not found`

**Step 3: Implement `up` in `cdx.sh`**

Add after `cdx` function, before `_cdx_init`:
```bash
up() {
  local inspect=0
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i) inspect=1; shift ;;
      *)  args+=("$1"); shift ;;
    esac
  done

  local spec="${args[0]:-}"
  local count=1
  local subpath=""

  if [[ -n "$spec" ]]; then
    if [[ "$spec" =~ ^([0-9]+)(/(.*))?$ ]]; then
      count="${BASH_REMATCH[1]}"
      subpath="${BASH_REMATCH[3]:-}"
    fi
  fi

  local target=""
  local i
  for ((i = 0; i < count; i++)); do
    target="../$target"
  done
  [[ -n "$subpath" ]] && target="${target}${subpath}"
  [[ -z "$target" ]] && target=".."

  if [[ $inspect -eq 1 ]]; then
    cdx -i "$target"
  else
    cdx "$target"
  fi
}
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/test_up.bats
```
Expected: 5 tests, 0 failures

**Step 5: Commit**

```bash
git add cdx.sh tests/test_up.bats
git commit -m "feat: up command"
```

---

## Task 8: Hook — `preview.sh`

**Files:**
- Modify: `hooks/preview.sh`
- Test: `tests/hooks/test_preview.bats`

**Step 1: Write failing test**

`tests/hooks/test_preview.bats`:
```bash
load '../../tests/test_helper'

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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/hooks/test_preview.bats
```
Expected: FAIL

**Step 3: Implement `hooks/preview.sh`**

```bash
# cdx hook: preview — show directory contents on enter

cdx_hook_preview() {
  local mode="$1" dir="$2"
  if command -v eza &>/dev/null; then
    eza ${CDX_LS_ARGS:---color=auto} "$dir"
  elif command -v exa &>/dev/null; then
    exa ${CDX_LS_ARGS:---color=auto} "$dir"
  else
    ls ${CDX_LS_ARGS:--lh} "$dir"
  fi
}

cdx_register_hook sync cdx_hook_preview
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/hooks/test_preview.bats
```
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add hooks/preview.sh tests/hooks/test_preview.bats
git commit -m "feat: preview hook"
```

---

## Task 9: Hook — `git.sh`

**Files:**
- Modify: `hooks/git.sh`
- Test: `tests/hooks/test_git.bats`

**Step 1: Write failing test**

`tests/hooks/test_git.bats`:
```bash
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
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/hooks/test_git.bats
```
Expected: FAIL

**Step 3: Implement `hooks/git.sh`**

```bash
# cdx hook: git — show git status on enter

cdx_hook_git() {
  local mode="$1" dir="$2"
  [[ -d "$dir/.git" ]] || return 0
  command -v git &>/dev/null || return 0
  git -C "$dir" status -sb
}

cdx_register_hook sync cdx_hook_git
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/hooks/test_git.bats
```
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add hooks/git.sh tests/hooks/test_git.bats
git commit -m "feat: git hook"
```

---

## Task 10: Hook — `notify.sh`

**Files:**
- Modify: `hooks/notify.sh`

No unit test — depends on `notify-send` desktop integration. Manual verification only.

**Step 1: Implement `hooks/notify.sh`**

```bash
# cdx hook: notify — send desktop notification on enter

cdx_hook_notify() {
  local mode="$1" dir="$2"
  [[ "$mode" = "enter" ]] || return 0
  command -v notify-send &>/dev/null || return 0
  notify-send "cdx" "Entered: $dir" --expire-time=2000 &>/dev/null
}

cdx_register_hook async cdx_hook_notify
```

**Step 2: Commit**

```bash
git add hooks/notify.sh
git commit -m "feat: notify hook"
```

---

## Task 11: Hook — `docker.sh`

**Files:**
- Modify: `hooks/docker.sh`
- Test: `tests/hooks/test_docker.bats`

**Step 1: Write failing test**

`tests/hooks/test_docker.bats`:
```bash
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
  # mock docker command
  docker() { echo "docker context use: $*"; }
  export -f docker
  run cdx_hook_docker enter "$TESTDIR"
  assert_output --partial "my-context"
}

@test "docker hook is registered as async" {
  [[ " ${__CDX_HOOKS_ASYNC[*]} " == *" cdx_hook_docker "* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
./tests/bats/bin/bats tests/hooks/test_docker.bats
```
Expected: FAIL

**Step 3: Implement `hooks/docker.sh`**

```bash
# cdx hook: docker — switch docker context on enter

cdx_hook_docker() {
  local mode="$1" dir="$2"
  local context_file="$dir/.docker-context"
  [[ -f "$context_file" ]] || return 0
  command -v docker &>/dev/null || return 0
  local context
  context="$(cat "$context_file")"
  [[ -n "$context" ]] || return 0
  docker context use "$context"
}

cdx_register_hook async cdx_hook_docker
```

**Step 4: Run tests to verify they pass**

```bash
./tests/bats/bin/bats tests/hooks/test_docker.bats
```
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add hooks/docker.sh tests/hooks/test_docker.bats
git commit -m "feat: docker hook"
```

---

## Task 12: Bash completion

**Files:**
- Modify: `completions/cdx.bash`

**Step 1: Implement `completions/cdx.bash`**

```bash
# cdx bash completion

_cdx_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "${COMP_WORDS[0]}" in
    up)
      # complete numeric/path spec: "3" or "3/subdir"
      if [[ "$cur" =~ ^[0-9] ]]; then
        local num="${cur%%/*}"
        local rest="${cur#*/}"
        if [[ "$cur" == */* ]]; then
          local partial_path
          partial_path="$(printf '../%.0s' $(seq 1 "$num"))$rest"
          COMPREPLY=($(compgen -d -- "$partial_path" | sed "s|^../*/|${num}/|"))
        fi
      else
        COMPREPLY=($(compgen -d -- "$cur"))
      fi
      ;;
    cdx)
      COMPREPLY=($(compgen -d -- "$cur"))
      ;;
  esac
}

complete -F _cdx_complete cdx
complete -F _cdx_complete up
```

**Step 2: Commit**

```bash
git add completions/cdx.bash
git commit -m "feat: bash completion"
```

---

## Task 13: Zsh completion

**Files:**
- Modify: `completions/cdx.zsh`

**Step 1: Implement `completions/cdx.zsh`**

```zsh
#compdef cdx up

_cdx() {
  _arguments \
    '-i[inspect mode — preview without changing directory]' \
    '1:directory:_directories'
}

_up() {
  _arguments \
    '-i[inspect mode]' \
    '1:N[/subpath]:_directories'
}

case "$service" in
  cdx) _cdx ;;
  up)  _up ;;
esac
```

**Step 2: Commit**

```bash
git add completions/cdx.zsh
git commit -m "feat: zsh completion"
```

---

## Task 14: Install script

**Files:**
- Modify: `install.sh`

**Step 1: Implement `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

CDX_REPO="https://raw.githubusercontent.com/<org>/cdx/main"
CDX_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/cdx"
CDX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cdx"

_detect_shell_rc() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

_download() {
  local url="$1" dest="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget -qO "$dest" "$url"
  else
    echo "cdx install: curl or wget required" >&2
    exit 1
  fi
}

_patch_rc() {
  local rc="$1"
  local line="source \"$CDX_DATA/cdx.sh\""
  if grep -qF "$line" "$rc" 2>/dev/null; then
    echo "cdx: already sourced in $rc"
  else
    echo "" >> "$rc"
    echo "# cdx — extensible cd wrapper" >> "$rc"
    echo "$line" >> "$rc"
    echo "cdx: added source line to $rc"
  fi
}

echo "Installing cdx..."

mkdir -p "$CDX_DATA"
mkdir -p "$CDX_CONFIG/hooks"

# Download core
_download "$CDX_REPO/cdx.sh" "$CDX_DATA/cdx.sh"

# Download hooks
for hook in preview git notify docker; do
  _download "$CDX_REPO/hooks/${hook}.sh" "$CDX_CONFIG/hooks/${hook}.sh"
done

# Write default config (only if not present)
if [[ ! -f "$CDX_CONFIG/config.sh" ]]; then
  cat > "$CDX_CONFIG/config.sh" <<'EOF'
# cdx config — edit to enable/disable hooks
# Add custom hooks to ~/.config/cdx/hooks/ and list them here
CDX_HOOKS_ENABLED=(preview git)
EOF
  echo "cdx: created $CDX_CONFIG/config.sh"
else
  echo "cdx: $CDX_CONFIG/config.sh already exists, skipping"
fi

# Install completions if directories exist
SHELL_RC="$(_detect_shell_rc)"
if [[ "$SHELL_RC" == *zshrc* ]] && [[ -d "${FPATH%%:*}" ]]; then
  _download "$CDX_REPO/completions/cdx.zsh" "${FPATH%%:*}/_cdx"
elif [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
  _download "$CDX_REPO/completions/cdx.bash" \
    "$HOME/.local/share/bash-completion/completions/cdx"
fi

_patch_rc "$SHELL_RC"

echo ""
echo "cdx installed."
echo "Restart your shell or run: source $SHELL_RC"
echo ""
echo "To use cdx as cd: add 'alias cd=cdx' to $CDX_CONFIG/config.sh"
```

**Step 2: Make executable**

```bash
chmod +x install.sh
```

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: install script"
```

---

## Task 15: Full test suite run

**Step 1: Run all tests**

```bash
./tests/bats/bin/bats tests/ tests/hooks/
```
Expected: all tests pass, 0 failures

**Step 2: Smoke test in current shell**

```bash
# In a new shell:
CDX_CONFIG_DIR="$PWD/tests/fixtures/config" source ./cdx.sh
cdx /tmp && echo "OK: entered /tmp"
cdx -i "$HOME" && echo "OK: inspect mode (stayed in /tmp)"
up && echo "OK: up"
```

**Step 3: Verify line count**

```bash
wc -l cdx.sh
```
Expected: < 100 lines (well under the 500-line spec limit)

---

## Summary

| Component | File | Status |
|---|---|---|
| Core engine | `cdx.sh` | Tasks 2–7 |
| `up` command | `cdx.sh` | Task 7 |
| Preview hook | `hooks/preview.sh` | Task 8 |
| Git hook | `hooks/git.sh` | Task 9 |
| Notify hook | `hooks/notify.sh` | Task 10 |
| Docker hook | `hooks/docker.sh` | Task 11 |
| Bash completion | `completions/cdx.bash` | Task 12 |
| Zsh completion | `completions/cdx.zsh` | Task 13 |
| Install script | `install.sh` | Task 14 |
