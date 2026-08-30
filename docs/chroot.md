# chroot internals

Technical reference for the rooted chroot implementation (`lib/chroot.sh`).

## Bind mounts

On `start`, AndroidLinux bind-mounts these kernel filesystems into the rootfs:

```
/dev       -> <rootfs>/dev
/sys       -> <rootfs>/sys
/proc      -> <rootfs>/proc
/dev/pts   -> <rootfs>/dev/pts
```

Each mount is created with `mount --bind` via `su -c`. Before mounting, the target is
checked against `/proc/mounts`; already-mounted targets are skipped. Missing sources are
skipped with a debug note rather than an error.

## Idempotence

`start` can be run repeatedly. It only creates mounts that are not already present, so it
is safe to call from scripts or the menu multiple times.

## Cleanup

`stop` unmounts in reverse order (`dev/pts`, `proc`, `sys`, `dev`). A lazy unmount
(`umount -l`) is attempted as a fallback if a busy mount refuses to unmount.

## DNS

`start` writes `etc/resolv.conf` inside the rootfs (default `1.1.1.1`, overridable via
the `DNS` config key). Android's own resolver is never modified.

## Namespaces

If the kernel supports mount namespaces they may be used, but AndroidLinux never assumes
namespace support. Absence of namespaces simply means mounts persist until `stop`.

## Entering

```
run_as_root env -i HOME=/root TERM=$TERM PATH=... chroot <rootfs> /bin/bash -l
```

Falls back to `/bin/sh` if the rootfs has no bash.
