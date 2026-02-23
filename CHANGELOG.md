# Changelog

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
