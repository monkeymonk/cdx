# cdx

`cdx` is a minimal, extensible wrapper around `cd` that dispatches lifecycle hooks when you enter a directory. It supports synchronous and asynchronous hooks, per-directory config via `.cdxrc`, and an `up` helper for climbing parent directories. If `zoxide` is installed, `cdx` uses it to resolve targets before falling back to a normal `cd`.

## Install

Use the install script (it downloads the core file, default hooks, and completions):

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/cdx/main/install.sh | bash
```

What the installer does:
- Installs `cdx.sh` to `~/.local/share/cdx/cdx.sh`.
- Creates `~/.config/cdx/` with `config.sh` and `hooks/` (if missing).
- Adds `source ~/.local/share/cdx/cdx.sh` to your shell rc file.
- Installs completions if standard locations exist.

To uninstall, remove the source line from your rc file and delete `~/.local/share/cdx/` and `~/.config/cdx/`.

### Completions

The installer enables completions when it detects standard shell completion directories. If you install manually, you can source one of the bundled completion files from your shell rc:

```bash
# bash
source /path/to/cdx/completions/cdx.bash

# zsh
source /path/to/cdx/completions/cdx.zsh
```

## Usage

Load `cdx` into your shell (installer already does this):

```bash
source ~/.local/share/cdx/cdx.sh
```

Basic usage:

```bash
cdx /path/to/project
cdx            # go to $HOME
cdx -i /path   # inspect mode (no directory change)
cdx --help     # show help
cdx -- /path   # stop flag parsing (treat next arg as path)
```

Use `up` to go up multiple levels:

```bash
up        # one level up
up 3      # three levels up
up 2/src  # up two, then into src
up -i 2   # inspect without changing directories
up --help # show help
```

### Options and Parameters

`cdx`:
- `-i`: inspect mode (do not change directories; hooks still run).
- `-h`, `--help`: show help.
- `--`: end of options; treat the next argument as a literal path.
- `PATH`: optional target path; defaults to `$HOME`.

`up`:
- `-i`: inspect mode (delegates to `cdx -i`).
- `-h`, `--help`: show help.
- `N`: number of parent levels (default `1`).
- `N/subpath`: go up `N` levels, then into `subpath`.

## Hooks

Hooks are shell functions registered via `cdx_register_hook` and are called on each navigation with two arguments:

```bash
cdx_hook_name() {
  local mode="$1"  # enter | inspect
  local dir="$2"   # absolute target path
}
```

Hook types:
- `sync`: runs in order, blocks navigation.
- `async`: runs in the background, fire-and-forget.

Example custom hook:

```bash
# ~/.config/cdx/hooks/hello.sh
cdx_hook_hello() {
  local mode="$1" dir="$2"
  [[ "$mode" = "enter" ]] || return 0
  echo "Hello from $dir"
}

cdx_register_hook sync cdx_hook_hello
```

Enable it in `config.sh`:

```bash
CDX_HOOKS_ENABLED=(preview git hello)
```

Built-in hooks (shipped by the installer):
- `preview` (sync): lists directory contents (uses `eza`, `exa`, or `ls`).
- `git` (sync): shows `git status -sb` when `.git/` is present.
- `notify` (async): desktop notification via `notify-send`.
- `docker` (async): switches Docker context from `.docker-context`.

## Configuration: `~/.config/cdx/*`

All user configuration lives under `~/.config/cdx/` (or `$XDG_CONFIG_HOME/cdx`):
- `config.sh`: global config sourced at shell startup.
- `hooks/`: hook scripts (one file per hook name).

Example `config.sh`:

```bash
# ~/.config/cdx/config.sh
CDX_HOOKS_ENABLED=(preview git)
```

### Configuration Variables

- `CDX_CONFIG_DIR`: override config root (defaults to `~/.config/cdx`).
- `CDX_HOOKS_ENABLED`: list of hook names to load (e.g., `preview git notify`).
- `CDX_LS_ARGS`: arguments passed to `eza`/`exa`/`ls` in the preview hook.

Per-directory config via `.cdxrc`:

```bash
# /path/to/project/.cdxrc
CDX_HOOKS_ENABLED=(preview git docker)
```

`.cdxrc` is sourced after resolving the target directory and before hook dispatch. This allows per-project behavior, such as enabling additional hooks or setting hook-specific environment variables.

## Development

Run tests with the bundled Bats runner:

```bash
./tests/bats/bin/bats tests/ tests/hooks/
```

## Shell Integration Examples

### fzf + cdx (Bash)

```bash
cdxf() {
  local dir
  dir="$(find . -type d 2>/dev/null | fzf)"
  [[ -n "$dir" ]] && cdx "$dir"
}
```

### fzf + cdx (Zsh)

```zsh
cdxf() {
  local dir
  dir="$(find . -type d 2>/dev/null | fzf)"
  [[ -n "$dir" ]] && cdx "$dir"
}
```
