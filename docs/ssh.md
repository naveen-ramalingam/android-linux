# SSH

AndroidLinux can install an OpenSSH server inside the Linux guest so you can connect
from another machine.

## Install & Auto-Start

```bash
android-linux ssh install
```

The installer:

- Installs `openssh-server` (Debian/Ubuntu) or `openssh` (Alpine/Arch).
- Sets the port to **2222** by default (port 22 is often used by Android).
- Generates host keys.
- Creates the `android` user and asks for a password (interactive).
- **Automatically starts the SSH daemon (`sshd`) on completion.**

## Manage

```bash
android-linux ssh status    # Check if sshd is running
android-linux ssh start     # Start sshd
android-linux ssh stop      # Stop sshd
```

## Connect

Find your device's IP with `android-linux ip`, then connect:

```bash
ssh -p 2222 android@<device-ip>
```

### Clients

- **macOS / Linux:** built-in `ssh` in Terminal.
- **Windows:** PowerShell `ssh`, Windows Terminal, or PuTTY.
- **Android:** Termux `ssh` or any SSH client app (e.g. JuiceSSH, ConnectBot).

## Security notes

- SSH binds to the device's local network only.
- It is **not** exposed to the public internet by default.
- Prefer SSH keys over passwords for regular use.
- Use a non-default port to avoid conflicts and casual scanning.
