# Desktop & VNC

AndroidLinux can install a lightweight desktop (XFCE or LXQt) and expose it over VNC. Desktops are
**optional** and can be selected during first-time setup or installed later.

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

This installs:
- The desktop environment (`xfce4` or `lxqt-core`)
- `tigervnc-standalone-server` and `dbus-x11`
- Fonts and terminal emulator
- Generates or prompts for a VNC password
- Configures `~/.vnc/xstartup` and **automatically starts the VNC server**

## Management Commands

```bash
android-linux desktop status     # check if VNC server is running
android-linux desktop start      # starts VNC on :1 (port 5901)
android-linux desktop stop       # stops VNC server
```

## How to Connect

### 1. View Desktop on Your Android Phone
Use a free VNC client app from F-Droid or Play Store:
- **[AVNC](https://f-droid.org/packages/com.gaurav.avnc/)** (recommended on F-Droid)
- **[bVNC](https://f-droid.org/packages/com.iiordanov.freebVNC/)** or RealVNC

**Connection Settings:**
- **Host / IP:** `127.0.0.1` (or `localhost`)
- **Port:** `5901`
- **Password:** (your VNC password set during install)

### 2. View Desktop from Your Computer (Mac / Linux / Windows)
By default, VNC is bound to localhost for security. Connect securely via SSH tunnel:

```bash
# 1. Forward the VNC port over SSH:
ssh -p 2222 -L 5901:127.0.0.1:5901 android@<device-ip>

# 2. Open any VNC viewer on your computer and connect to:
localhost:5901
```

*(To expose VNC directly to your local Wi-Fi network without an SSH tunnel, set `VNC_LOCALHOST=0` in `~/.config/android-linux/config.conf` and connect directly to `<device-ip>:5901`)*

## Security notes

- VNC authentication is weak; the localhost default + SSH tunnel is strongly preferred.
- A VNC password can be set during setup or updated with `vncpasswd` inside the guest.

## Termux:X11

If you have Termux:X11 installed, you can also run graphical apps directly by exporting `DISPLAY`
instead of using VNC. VNC remains the universal fallback that works on all devices and clients.
