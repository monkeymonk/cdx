# cdx

`cdx` is a minimal, extensible wrapper around `cd` that dispatches lifecycle hooks when you enter a directory. It supports synchronous and asynchronous hooks, per-directory config via `.cdxrc` (or `.cdxrc.fish`), and `--up` / `-N` shorthand for climbing parent directories. A pluggable resolver chain (zoxide, zsh-z, z, z.lua, autojump) resolves fuzzy targets before falling back to a normal `cd`. Supports **bash**, **zsh**, and **fish**.

![cdx demo](demo.gif)

## Install

Use the install script (it downloads the core file, default hooks, and completions):

```bash
curl -fsSL https://raw.githubusercontent.com/monkeymonk/cdx/main/install.sh | bash
```

The installer detects your shell (bash, zsh, or fish) from `$SHELL` and picks the matching files. To override detection, set `CDX_INSTALL_SHELL`:

```bash
CDX_INSTALL_SHELL=fish bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkeymonk/cdx/main/install.sh)"
```

What the installer does:

- Installs the core file (`cdx.sh` for bash/zsh, `cdx.fish` for fish) to `~/.local/bin/`.
- Creates `~/.config/cdx/` with a config file (`config.sh` or `config.fish`) and matching `hooks/` (if missing).
- Adds a source line to your shell rc file (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`).
- Installs completions to the appropriate location (`~/.local/share/bash-completion/completions/` for bash, next to the script for zsh, `~/.config/fish/completions/` for fish).

To uninstall, remove the source line from your rc file and delete `~/.local/bin/cdx.{sh,fish}` and `~/.config/cdx/`.

### Completions

**Zsh:** Completions are automatically registered when `cdx.sh` is sourced in an interactive zsh session. It locates `completions/cdx.zsh` relative to the script (or via `$fpath`) and registers completions for `cdx` — and for `cd` too if it's aliased to `cdx`. No manual setup needed.

**Bash:** The installer places the completion file in `~/.local/share/bash-completion/completions/`. If you install manually, source it from your rc:

```bash
source /path/to/cdx/completions/cdx.bash
```

**Fish:** Completions are placed in `~/.config/fish/completions/cdx.fish` and autoloaded by fish. Sourcing `cdx.fish` also falls back to loading completions from alongside the script.

## Usage

Load `cdx` into your shell (installer already does this):

```bash
# bash / zsh
source ~/.local/bin/cdx.sh
```

```fish
# fish
source ~/.local/bin/cdx.fish
```

Basic usage:

```bash
cdx /path/to/project
cdx            # go to $HOME
cdx -i /path   # inspect mode (no directory change)
cdx --help     # show help
cdx --version  # show version
cdx -- /path   # stop flag parsing (treat next arg as path)
```

Go up parent directories with `--up` or the `-N` shorthand:

```bash
cdx --up          # go up 1 level
cdx --up 3        # go up 3 levels
cdx --up 2/src    # go up 2 levels, then into src/
cdx -1            # shorthand: up 1 level
cdx -3            # shorthand: up 3 levels
cdx -2/src        # shorthand: up 2 levels, then into src/
cdx -i --up 2     # inspect mode, up 2 levels
```

Recommended shell aliases:

```bash
# bash / zsh
alias ..='cdx --up'
alias ...='cdx --up 2'
alias ....='cdx --up 3'
```

```fish
# fish
alias .. 'cdx --up'
alias ... 'cdx --up 2'
alias .... 'cdx --up 3'
```

### Options and Parameters

`cdx`:

- `-i`: inspect mode (do not change directories; hooks still run).
- `-h`, `--help`: show help.
- `-v`, `--version`: show version.
- `--`: end of options; treat the next argument as a literal path.
- `PATH`: optional target path; defaults to `$HOME`.

`cdx --up` / `cdx -N`:

- `--up [N[/subpath]]`: go up N parent levels (default 1), optionally into subpath.
- `-N[/subpath]`: shorthand, e.g. `cdx -2/src`.
- `-i`: inspect mode.

## Hooks

Hooks are shell functions registered via `cdx_register_hook` and are called on each navigation with two arguments: `mode` (`enter` or `inspect`) and `dir` (absolute target path).

Bash / zsh:

```bash
cdx_hook_name() {
  local mode="$1" dir="$2"
}
```

Fish:

```fish
function cdx_hook_name --argument-names mode dir
end
```

Hook types:

- `sync`: runs in order, blocks navigation.
- `async`: runs in the background, fire-and-forget.

### Hook Context

By default, hooks only run in interactive shells. You can control this with an optional third argument to `cdx_register_hook`:

| Context          | Interactive shell | Non-interactive shell (CI, editors, scripts) |
|------------------|:-:|:-:|
| `interactive`    | yes | — |
| `noninteractive` | — | yes |
| `all`            | yes | yes |

```bash
cdx_register_hook sync cdx_hook_preview                # interactive only (default)
cdx_register_hook sync cdx_hook_env all                 # both contexts
cdx_register_hook async cdx_hook_log noninteractive     # non-interactive only
```

This prevents hooks like `preview` or `git` from producing unwanted output in non-interactive shells (e.g. when `cd` is aliased to `cdx` inside CI runners or editor subprocesses).

### Custom Hook Example

Bash / zsh:

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

Fish:

```fish
# ~/.config/cdx/hooks/hello.fish
function cdx_hook_hello --argument-names mode dir
    test "$mode" = enter; or return 0
    echo "Hello from $dir"
end

cdx_register_hook sync cdx_hook_hello
```

Enable it in `config.fish`:

```fish
set -g CDX_HOOKS_ENABLED preview git hello
```

Built-in hooks (shipped by the installer):

- `preview` (sync): lists directory contents (uses `eza`, `exa`, or `ls`).
- `git` (sync): shows `git status -sb` when `.git/` is present.
- `notify` (async): desktop notification via `notify-send`.
- `docker` (async): switches Docker context from `.docker-context`.

## Configuration: `~/.config/cdx/*`

All user configuration lives under `~/.config/cdx/` (or `$XDG_CONFIG_HOME/cdx`):

- `config.sh` (bash/zsh) or `config.fish` (fish): global config sourced at shell startup.
- `hooks/`: hook scripts (`<name>.sh` for bash/zsh, `<name>.fish` for fish — one file per hook name).

Example `config.sh`:

```bash
# ~/.config/cdx/config.sh
CDX_HOOKS_ENABLED=(preview git)
```

Example `config.fish`:

```fish
# ~/.config/cdx/config.fish
set -g CDX_HOOKS_ENABLED preview git
```

### Configuration Variables

- `CDX_CONFIG_DIR`: override config root (defaults to `~/.config/cdx`).
- `CDX_HOOKS_ENABLED`: list of hook names to load (e.g., `preview git notify`).
- `CDX_RESOLVERS`: override resolver order (e.g., `CDX_RESOLVERS=(zoxide z)`). By default, cdx auto-detects installed resolvers from: zoxide, zsh-z, z, z.lua, autojump. Fish does not support the zsh-specific `zsh-z` resolver and auto-detects from: zoxide, z, z.lua, autojump.
- `CDX_CDXRC`: set to `0` to disable per-directory `.cdxrc` sourcing. (Fish sources `.cdxrc.fish` instead of `.cdxrc`.)
- `CDX_LS_ARGS`: arguments passed to `eza`/`exa`/`ls` in the preview hook.

Per-directory config via `.cdxrc` (bash/zsh) or `.cdxrc.fish` (fish):

```bash
# /path/to/project/.cdxrc
CDX_HOOKS_ENABLED=(preview git docker)
```

```fish
# /path/to/project/.cdxrc.fish
set -g CDX_HOOKS_ENABLED preview git docker
```

The file is sourced after resolving the target directory and before hook dispatch. This allows per-project behavior, such as enabling additional hooks or setting hook-specific environment variables.

## Development

Run tests with the bundled Bats runner:

```bash
./tests/bats/bin/bats tests/ tests/hooks/
```

## Shell Integration Examples

Bash / zsh:

```bash
cdxf() {
  local dir
  dir="$(find . -type d 2>/dev/null | fzf)"
  [[ -n "$dir" ]] && cdx "$dir"
}
```

Fish:

```fish
function cdxf
    set -l dir (find . -type d 2>/dev/null | fzf)
    test -n "$dir"; and cdx $dir
end
```
