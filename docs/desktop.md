# Desktop & VNC

AndroidLinux can install a lightweight desktop and expose it over VNC. Desktops are
**optional** and never installed automatically.

## Recommendations by RAM

| RAM | Recommendation |
|-----|----------------|
| < 2 GB | No desktop (headless) |
| 2–4 GB | XFCE possible |
| ≥ 4 GB | XFCE recommended |

These are suggestions; advanced users can override.

## Install

```bash
android-linux desktop install xfce     # or lxqt
```

This installs the desktop packages, `dbus`, fonts, and a VNC server, then writes an
`xstartup` that launches the session. `systemd` is **not** required.

## Run

```bash
android-linux desktop start      # starts VNC on :1 (port 5901)
android-linux desktop status
android-linux desktop stop
```

Connect with any VNC viewer to `<device-ip>:5901`. The address is printed after start.

## Termux:X11

If you have Termux:X11, you can also run graphical apps directly by exporting `DISPLAY`
instead of using VNC. VNC remains the universal fallback.

## Display methods

1. **VNC** — works everywhere (compatibility fallback).
2. **Termux:X11** — smoother, when available.
