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

By default VNC binds to **localhost only** (`VNC_LOCALHOST=1`) and a random VNC
password is generated during `desktop install`. Connect from your computer with an
SSH tunnel:

```bash
ssh -p 2222 -L 5901:localhost:5901 android@<device-ip>
# then point your VNC viewer at localhost:5901
```

To expose VNC to the local network instead (only on a trusted network), set
`VNC_LOCALHOST=0` in your config, then connect a VNC viewer to `<device-ip>:5901`.

## Security notes

- VNC authentication is weak; the localhost default + SSH tunnel is strongly preferred.
- A random VNC password is set automatically. Re-generate with `vncpasswd` inside the
  guest if needed.

## Termux:X11

If you have Termux:X11, you can also run graphical apps directly by exporting `DISPLAY`
instead of using VNC. VNC remains the universal fallback.

## Display methods

1. **VNC** — works everywhere (compatibility fallback).
2. **Termux:X11** — smoother, when available.
