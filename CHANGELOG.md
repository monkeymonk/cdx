# Changelog

## v0.2.8
- Extract `_cdx_dispatch` back into standalone function for testability and reduced `cdx()` complexity.
- Fix hook deduplication: use `__CDX_HOOK_CONTEXT` associative array instead of fragile string scan; re-registration now updates context.
- Fix `_cdx_resolver_z` leaking stderr to stdout (`2>&1` → `2>/dev/null`).
- Add snapshot guard: fall back to `builtin cd` when cdx is loaded via shell snapshot without full initialization (e.g. Claude Code, Codex).
- Validate `--up` spec: non-numeric or zero values now warn and return error instead of silently defaulting.
- Add resolver dirty flag to avoid redundant re-caching on every resolve call.
- Standardize on `typeset -f` over `declare -f` for cross-shell consistency.
- Prefer `typeset -gA` (zsh-native) over `declare -gA` for associative array init.
- Move `local` declaration outside loop in `_cdx_init`.

## v0.2.7
- Add context-aware hook dispatch: hooks can now specify `interactive`, `noninteractive`, or `all` as a third argument to `cdx_register_hook`.
- Existing hooks default to `interactive`, preserving backward compatibility.
- Fix spurious "permission denied" errors when `cd` is aliased to `cdx` in non-interactive shells (e.g. Claude Code, CI, editor subprocesses).

## v0.2.6
- Cache resolver availability at init time to avoid repeated `command -v`/`typeset -f` lookups.
- Eliminate subshell fork on enter path by using `$PWD` after `builtin cd`.
- Cache ls command (`eza`/`exa`/`ls`) at source time in preview hook.
- Unify zsh/bash `-N` flag parsing into a single case branch.
- Replace `cat` with `read` in docker hook to avoid external process fork.
- Add `CDX_CDXRC=0` option to disable per-directory `.cdxrc` sourcing.
- Guard `_cdx_init` to only run in interactive shells.
- Guard hook dispatch against unset/removed hook functions.
- Fix stale `_cdx_dispatch` test references (function removed in v0.2.3).
- Fix hook test load paths to work when run from project root.

## v0.2.5
- Add pluggable resolver chain: support zoxide, zsh-z, z, z.lua, and autojump for fuzzy directory jumping.
- Auto-detect installed resolvers; override with `CDX_RESOLVERS` in config.
- Fix preview hook `ls` fallback using `-lh` instead of `--color=auto` to match eza/exa output style.

## v0.2.4
- Auto-register zsh completions when `cdx.sh` is sourced in an interactive session; also registers for `cd` if aliased to `cdx`.
- Update README completions section to reflect auto-registration.

## v0.2.3
- Inline hook dispatch directly into `cdx()`, removing the internal `_cdx_dispatch` helper.

## v0.2.2
- Add VHS demo tape and GIF to showcase core features.
- Add demo GIF to README.

## v0.2.1
- Fix `-N` shorthand not matching in zsh when `EXTENDED_GLOB` or similar options are active; use regex pre-check instead of `case` pattern.
- Inspect mode now prints the resolved target path before running hooks.

## v0.2.0
- **Breaking:** Remove `cdx_up` function; navigate up with `cdx --up [N[/subpath]]` instead.
- Add `-N[/subpath]` shorthand for going up N levels (e.g. `cdx -3`, `cdx -2/src`).
- Update bash and zsh completions for `--up` flag and `-N` shorthand; remove standalone `up` completion.
- **Breaking:** Installer now places `cdx.sh` in `~/.local/bin/cdx.sh` instead of `~/.local/share/cdx/cdx.sh`; existing installs are migrated automatically on next reinstall.
- Fix pre-existing `args[1]` index bug in `cdx()` argument parsing (had no user-visible effect).

## v0.1.6
- Deduplicate hook registration: `cdx_register_hook` skips if the function is already registered, preventing double-execution on re-source or duplicate `CDX_HOOKS_ENABLED` entries.
- Add mode guard to `docker` hook: context switching now skipped in inspect mode.
- Use `jq` for GitHub API JSON parsing in installer when available, falling back to `sed`.
- Add `-v`/`--version` to completions for `cdx` and `up` (bash and zsh).
- Fix version string in `--help` output to use a single source of truth.
- Document mode-intent in all built-in hook files.

## v0.1.5
- Install from the latest git tag when available (fallback to `main`).

## v0.1.4
- Fix installer crash when `FPATH` is unset in bash.
- Avoid zsh parse error when an `up` alias exists.
- Cache-bust raw GitHub downloads in the installer.
- Fix zsh argument indexing so `cdx` changes directories correctly.
- Declare argument arrays in zsh so `cdx` and `up` parse args reliably.
- Provide `cdx_up` helper and let users define their own `up` alias.

## v0.1.3
- Fix installer crash when `FPATH` is unset in bash.

## v0.1.2
- Add MIT license, contribution guidelines, and repo editor attributes.
- Add `--help` output for `cdx` and `up`, plus completions.
- Document help flags in the README.

## v0.1.1
- Improve bash and zsh completion behavior for `cdx` and `up`, including `-i` support.
- Document manual completion setup in the README.

## v0.1.0
- Core `cdx` command with sync/async hooks and inspect mode.
- `up` helper for parent navigation.
- Built-in hooks: `preview`, `git`, `notify`, `docker`.
- Bash and Zsh completions.
- Installer script for user-level setup.
- Optional `zoxide` resolution when available.
