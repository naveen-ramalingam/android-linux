# PRoot internals

Technical reference for the non-root PRoot implementation (`lib/proot.sh`).

## What PRoot does

PRoot uses `ptrace` to intercept filesystem syscalls and rewrite paths, so a program
believes it is running at `/` while actually living inside `<rootfs>`. No privileges are
required.

## Bindings

`proot_enter` passes these bindings:

```
--bind=/dev
--bind=/proc
--bind=/sys
--bind=/dev/urandom:/dev/random
--bind=/sdcard      (if present)
--bind=/storage     (if present)
```

## Invocation

```
proot --kill-on-exit --root-id --cwd=/root <binds> -r <rootfs> \
      /usr/bin/env -i sh -c 'HOME=/root PATH=... exec /bin/bash -l'
```

`--kill-on-exit` cleans up traced processes when the shell exits. `--root-id` makes the
guest believe it runs as root.

## Extraction under PRoot

When `INSTALL_MODE=proot`, archives are extracted with
`proot --link2symlink tar ...` so hard links and device nodes are represented as symlinks
that a non-root filesystem can hold.

## Lifecycle

PRoot has no persistent mounts, so `start`/`stop` are no-ops and `status` reports
`on-demand`. Each `shell` launches a fresh session.

## Requirements

The `proot` binary must be in `PATH` (e.g. `pkg install proot` in Termux). If it is
missing, AndroidLinux explains how to install it rather than failing silently.
