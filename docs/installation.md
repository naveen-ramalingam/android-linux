# Installation

## Termux Setup (Android)

If you are running on an Android device (rooted or non-rooted), **Termux** provides the terminal environment.

### 1. Download Termux

> ⚠️ **DO NOT use the Google Play Store version of Termux.** It is deprecated and unmaintained. Use one of the official channels below:

* **[F-Droid](https://f-droid.org/en/packages/com.termux/)** *(Recommended)*: Download the Termux APK directly or install the F-Droid client.
* **[GitHub Releases](https://github.com/termux/termux-app/releases)**: Download the latest APK (e.g. `termux-app_v..._arm64-v8a.apk` or `universal`).

### 2. Recommended Android Settings for Termux

* **Battery Optimization**: Set Termux to **Unrestricted** / disable battery optimization in Android App Settings so background Linux operations aren't killed.
* **Storage Access (Optional)**: If you want Linux to access your phone's downloads and internal storage, run:
  ```bash
  termux-setup-storage
  ```

---

## One-command install

In Termux or your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh | bash
```

Or:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh)
```

The bootstrap automatically:

1. Detects Termux and auto-installs missing dependencies (`curl`, `git`, `proot`, `tar`, `xz-utils`).
2. Verifies CPU architecture.
3. Downloads AndroidLinux.
4. Validates the archive before extracting.
5. Installs the `android-linux` command into your PATH.
6. Launches the first-run wizard.

## Manual install

```bash
git clone https://github.com/naveen-ramalingam/android-linux.git
cd android-linux
./install.sh
```

## First-run wizard

Running `android-linux install` walks you through:

1. Welcome and license.
2. Device, root, architecture, storage, RAM, and kernel detection.
3. A recommended installation mode.
4. Distribution selection.
5. Install location.
6. Desktop and SSH options.
7. A summary with space requirements and a final confirmation.
8. Download → verify → extract → configure → test → finish.

## Non-interactive install

For scripting, combine flags:

```bash
android-linux install --distro alpine --proot --path /data/local/android-linux --yes
```

Use `--dry-run` first to preview exactly what would happen without changing anything.

## After install

```bash
android-linux shell     # enter your Linux
android-linux status    # confirm it's running
```
