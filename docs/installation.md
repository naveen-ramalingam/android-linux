# Installation

## One-command install

Replace `naveen-ramalingam` with your GitHub username after forking:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh)
```

The bootstrap:

1. Detects Termux.
2. Verifies architecture.
3. Verifies required utilities (`bash`, plus `curl`/`wget`/`git`).
4. Downloads the project (git clone if available, else archive).
5. Validates the archive before extracting.
6. Installs the `android-linux` command into your PATH.
7. Launches the first-run wizard.

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
