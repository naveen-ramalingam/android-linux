# Rooted mode (chroot)

If your device has root (Magisk, KernelSU, APatch, or any `su` implementation),
AndroidLinux can use a real `chroot`, which is faster and more compatible than PRoot.

## Detection

The installer probes several locations for a working `su`:

```
su  /system/xbin/su  /system/bin/su  /sbin/su  /su/bin/su  /debug_ramdisk/su
```

It verifies each by running `su -c id` and checking for `uid=0`. The root provider is
identified best-effort (`Magisk` / `KernelSU` / `APatch` / `Unknown`).

## What chroot mode does

- Bind-mounts `/proc`, `/sys`, `/dev`, `/dev/pts` into the rootfs.
- Writes a `resolv.conf` into the rootfs so networking works.
- Mounts are checked before being created and cleanly unmounted on `stop`.

## Lifecycle

```bash
android-linux start      # bind-mount kernel filesystems
android-linux shell      # enter the chroot
android-linux stop       # unmount cleanly
android-linux status     # running / stopped
```

## SELinux

With SELinux **Enforcing**, some mounts may be blocked. AndroidLinux will not change
SELinux for you. If chroot mounts fail, switch to PRoot mode:

```bash
android-linux install --proot
```

## Important

chroot mode never modifies Android. It only adds bind mounts that are removed on `stop`
or `uninstall`.
