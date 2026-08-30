# Supported devices

AndroidLinux is **device-agnostic**. It does not rely on a hard-coded device database.
Instead it detects capabilities at runtime, so it adapts to any Android device.

## Tested categories

- Samsung (Galaxy S/Note/A series)
- Google Pixel
- OnePlus
- Xiaomi / Redmi / POCO
- Motorola
- Sony Xperia
- HTC
- Nothing Phone
- ASUS
- Lenovo
- Other AOSP/LineageOS devices

## Reference test device

Development was validated against a **Samsung Galaxy S7 Edge (SM-G935F, hero2ltexx)**
running LineageOS 13 (Android 13), rooted, ARM64, kernel 3.18.140. This is only a
reference case — the project must adapt automatically to any other device.

## What detection covers

Manufacturer, model, codename, Android version, SDK, build ID, CPU architecture/ABI,
kernel version, RAM, storage, SELinux, root (and provider), Termux, BusyBox/Toybox,
mount/namespace capability, and available tooling (`tar`, `xz`, `zstd`, `curl`, `wget`,
`proot`, `chroot`, etc.).

## Adding a device profile

Only add a profile when a device genuinely needs a workaround:

```
profiles/devices/<codename>.sh
```

Define a `profile_apply` override there. Prefer capability detection over per-device
special-casing whenever possible.

## Reporting your device

If AndroidLinux works (or fails) on your device, open an issue with:

- `android-linux info` output
- Device model and Android version
- Root status

This helps grow real-world coverage.
