# Contributing

Thanks for contributing to `cdx`.

## Development setup

- Source `cdx.sh` to load the functions into your shell:
  - `source cdx.sh`
- Run the main command in a new shell session:
  - `cdx /tmp`
  - `cdx -i /tmp`

## Tests

Run the full test suite:

```sh
./tests/bats/bin/bats tests
```

Run a focused test file:

```sh
./tests/bats/bin/bats tests/test_core.bats
```

## Style

- Bash-only code; keep indentation to 2 spaces.
- Public functions use the `cdx_*` prefix.
- Internal helpers use the `_cdx_*` prefix.
- Hooks expose `cdx_hook_*` and are registered via `cdx_register_hook`.

## Safety

`cdx.sh` is sourced into a user’s shell. Avoid setting global `set -euo pipefail` in it,
since that would change the user’s shell behavior. Use local guards in functions instead.

## Releases

- Commit messages follow Conventional Commits (`feat:`, `chore:`).
- When incrementing a release tag, update `CHANGELOG.md` in the same change.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
