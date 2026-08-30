# Contributing to AndroidLinux

Thanks for your interest! AndroidLinux aims to be safe, portable, and beginner-friendly.

## Ground rules

- **Never** introduce code that flashes partitions, unlocks bootloaders, modifies
  `boot`/`recovery`/`system`, disables SELinux, or erases user data.
- Keep destructive operations confined to the AndroidLinux base directory and validated
  with the path-safety helpers in `lib/common.sh`.
- Prefer capability detection over hard-coded device assumptions.

## Development workflow

1. Fork the repository and create a branch: `git checkout -b my-feature`.
2. Make your changes in `lib/`, `bin/`, or `tests/`.
3. Run the checks below before opening a PR.

### Required checks

```bash
# Lint
shellcheck install.sh uninstall.sh bin/android-linux lib/*.sh profiles/*.sh tests/*.sh

# Test suite (no phone required)
bash tests/run-all.sh

# Smoke tests
./bin/android-linux --help
./bin/android-linux info
./bin/android-linux install --dry-run
```

## Style

- Target `bash`, but keep functions defensive (commands may be missing on Android).
- Use the shared helpers (`log_*`, `have_cmd`, `try`, `safe_remove`) instead of ad-hoc
  logic.
- No new hard dependencies for the core installer. Avoid Python/Node in the core path.
- Update `CHANGELOG.md` and docs when behavior changes.

## Commit messages

Use clear imperative summaries, e.g. `Add resume support to distro download`.

## Pull requests

- Keep PRs focused on one change.
- Describe the device/environment you tested on.
- Note any behavior changes and whether they need docs updates.

## Code of Conduct

Be respectful and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
