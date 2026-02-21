# cdx Design Document

Date: 2026-02-21

## Overview

`cdx` is an extensible, event-driven shell navigation tool that augments `cd` with a lifecycle hook system. It is Bash and Zsh compatible, minimal, and designed to be a stable primitive others can trust and extend.

---

## Repository Structure

```
cdx/
├── cdx.sh              # Core engine only — no hook logic
├── hooks/
│   ├── preview.sh      # ls/eza preview (sync)
│   ├── git.sh          # git status -sb (sync)
│   ├── notify.sh       # notify-send (async)
│   └── docker.sh       # docker context (async)
├── completions/
│   ├── cdx.bash
│   └── cdx.zsh
├── install.sh
└── README.md
```

---

## Installation

Single-script install via curl/wget:

```bash
curl -fsSL <url>/install.sh | bash
```

Install script does exactly:
1. Copies core to `~/.local/share/cdx/cdx.sh`
2. Creates `~/.config/cdx/` with default `config.sh` and `hooks/`
3. Appends `source ~/.local/share/cdx/cdx.sh` to `~/.bashrc` or `~/.zshrc` (idempotent)
4. Installs completions to standard locations if they exist

The install script does **not** set `alias cd=cdx`. The user decides how to invoke cdx.

---

## File Locations

| Path | Purpose |
|---|---|
| `~/.local/share/cdx/cdx.sh` | Core engine (managed by install/update) |
| `~/.config/cdx/config.sh` | User config (never overwritten by install) |
| `~/.config/cdx/hooks/` | Hooks — defaults shipped, user adds/edits freely |

---

## User Config (`~/.config/cdx/config.sh`)

```bash
CDX_HOOKS_ENABLED=(preview git)
```

Only hooks listed in `CDX_HOOKS_ENABLED` are loaded. To add a custom hook, drop a file in `~/.config/cdx/hooks/` and add its name to the array.

---

## Core Engine (`cdx.sh`)

### Responsibilities
- Override `cd` with a `cdx` function
- Implement `up`
- Parse arguments
- Resolve absolute paths
- Source `~/.config/cdx/config.sh`
- Load enabled hooks
- Source `.cdxrc` if present
- Dispatch sync then async hooks

### Must NOT contain
- Hook logic
- Knowledge of git, docker, preview tools, etc.

### Navigation Lifecycle

1. Parse args (flag: `-i` for inspect mode)
2. Resolve absolute target path
3. If inspect → skip `builtin cd`, set `mode=inspect`
4. Else → `builtin cd` or return error, set `mode=enter`
5. Source `.cdxrc` if present in new directory
6. Run sync hooks in registration order
7. Fire async hooks in subshells (fire-and-forget)

### Hook Registry

```bash
__CDX_HOOKS_SYNC=()
__CDX_HOOKS_ASYNC=()

cdx_register_hook() {
  local type="$1" fn="$2"  # type: sync | async
}
```

### Async Execution

```bash
(cdx_hook_notify "$mode" "$dir" &>/dev/null) &
```

Never blocks navigation.

---

## Hook System

### Hook signature

All hooks must conform to:

```bash
cdx_hook_<name>() {
  local mode="$1"   # enter | inspect
  local dir="$2"    # absolute resolved path
}
cdx_register_hook sync|async cdx_hook_<name>
```

### Loading

On startup, core iterates `CDX_HOOKS_ENABLED` and sources `~/.config/cdx/hooks/${name}.sh` for each entry. Unknown name = warning, not fatal.

### Initial hooks

| Hook | Type | Tool | Trigger |
|---|---|---|---|
| preview | sync | eza → exa → ls | always |
| git | sync | git | `.git` present |
| notify | async | notify-send | always |
| docker | async | docker | always |

---

## Per-Directory Config (`.cdxrc`)

Plain shell script, sourced after `builtin cd`. Can override `CDX_HOOKS_ENABLED` or any env var for that directory.

```bash
# .cdxrc
CDX_HOOKS_ENABLED=(preview git docker)
```

---

## `up` Command

Translates to `cdx`, fully delegates:

```
up          → cdx ..
up 3        → cdx ../../..
up 3/src    → cdx ../../../src
up -i 2     → cdx -i ../..
```

---

## Completions

- Bash: numeric completion for `up N`, directory completion for paths
- Zsh: `_arguments`-based
- Installed to standard locations if they exist, otherwise skipped

---

## Naming Conventions

- Tool: `cdx`
- Shell function: `cdx`
- Internal functions: `cdx_*`
- Environment variables: `CDX_*`
- Hook functions: `cdx_hook_<name>`

---

## Non-Goals

- No YAML/JSON config
- No plugin dependency graph
- No hook priorities
- No background daemon
- No framework abstractions
- No forced `alias cd=cdx`
