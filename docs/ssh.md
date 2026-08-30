# SSH

AndroidLinux can install an OpenSSH server inside the Linux guest so you can connect
from another machine.

## Install

```bash
android-linux ssh install
```

The installer:

- Installs `openssh-server` (Debian/Ubuntu) or `openssh` (Alpine/Arch).
- Sets the port to **2222** by default (port 22 is often used by Android).
- Generates host keys.
- Creates the `android` user and asks for a password (interactive).

## Start / stop

```bash
android-linux ssh start
android-linux ssh stop
```

## Connect

The address is printed after install/start:

```bash
ssh -p 2222 android@192.168.1.45
```

Replace `192.168.1.45` with your device's IP (shown by `android-linux network`).

### Clients

- **macOS / Linux:** built-in `ssh`.
- **Windows:** PowerShell `ssh`, PuTTY, or Windows Terminal.
- **Android:** Termux `ssh` or any SSH client app.

## Security notes

- SSH binds to the device's local network only.
- It is **not** exposed to the public internet by default.
- Prefer SSH keys over passwords for regular use.
- Use a non-default port to avoid conflicts and casual scanning.
