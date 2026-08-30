## Summary

<!-- One or two sentences describing the change and why it's needed. -->

## Type

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactor / maintenance

## Safety checklist

- [ ] Does not flash partitions, unlock bootloaders, or modify system/boot/recovery
- [ ] Destructive operations are confined to the AndroidLinux base and validated
- [ ] No new hard dependencies added to the core installer

## Testing

- [ ] `shellcheck` passes
- [ ] `bash tests/run-all.sh` passes
- [ ] Tested `android-linux info`, `doctor`, and `install --dry-run`
- [ ] Tested on a real device (specify below) or explain why not applicable

**Test device / environment:** <!-- e.g. Pixel 7, Android 14, rooted; or "CI only" -->

## Screenshots / logs (if applicable)
