#!/usr/bin/env bash
# install.sh - AndroidLinux bootstrap installer.
#
# One-command usage (replace naveen-ramalingam after you fork the repo):
#   bash <(curl -fsSL https://raw.githubusercontent.com/naveen-ramalingam/android-linux/main/install.sh)
#
# This downloads the project, installs the `android-linux` command into your
# PATH, and launches the first-run wizard. It does NOT modify Android.

set -Eeuo pipefail

# --- Configuration (edit naveen-ramalingam after forking) ----------------------------
REPO_USER="${ANDROID_LINUX_REPO_USER:-naveen-ramalingam}"
REPO_NAME="${ANDROID_LINUX_REPO_NAME:-android-linux}"
REPO_BRANCH="${ANDROID_LINUX_REPO_BRANCH:-main}"
REPO_GIT="https://github.com/${REPO_USER}/${REPO_NAME}.git"
REPO_TAR="https://github.com/${REPO_USER}/${REPO_NAME}/archive/refs/heads/${REPO_BRANCH}.tar.gz"

say()  { printf '[*] %s\n' "$*"; }
ok()   { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
err()  { printf '[x] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 1. Detect Termux / environment ----------------------------------------
IS_TERMUX=0
case "${PREFIX:-}" in *com.termux*) IS_TERMUX=1 ;; esac
[ -d /data/data/com.termux/files/usr ] && IS_TERMUX=1

if [ "$IS_TERMUX" = 1 ]; then
  say "Termux detected."
  INSTALL_PARENT="${PREFIX}/opt"
  BIN_TARGET="${PREFIX}/bin/android-linux"
else
  say "Termux not detected. Continuing in a generic shell environment."
  warn "For non-rooted phones, Termux is strongly recommended. See README."
  INSTALL_PARENT="${HOME:-/data/local/tmp}/.local/opt"
  BIN_TARGET="${HOME:-/data/local/tmp}/.local/bin/android-linux"
fi
APP_DIR="${INSTALL_PARENT}/android-linux"

# Safety guard: never (re)install into a protected system location.
case "$APP_DIR/" in
  "/opt/android-linux/"|"/system/"*|"/vendor/"*|"/product/"*|"/proc/"*|"/sys/"*|"/dev/"*|"/etc/"*|"/usr/"*|"/bin/"*|"/sbin/"*)
    die "Refusing to install into protected path: $APP_DIR (check \$HOME/\$PREFIX)" ;;
esac
[ -n "$APP_DIR" ] || die "Could not determine install directory"

# --- 2. Verify architecture -------------------------------------------------
ARCH_RAW="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH_RAW" in
  aarch64|arm64|armv8*) ok "Architecture: ARM64" ;;
  armv7l|armv7*|armeabi*) ok "Architecture: ARM32" ;;
  x86_64|amd64) ok "Architecture: x86_64" ;;
  i686|i386|x86) ok "Architecture: x86" ;;
  *) warn "Unrecognized architecture '$ARCH_RAW' - installation will still try to continue." ;;
esac

# --- 3. Verify required utilities ------------------------------------------
if ! have bash; then die "bash is required. In Termux: pkg install bash"; fi
DL=""
have curl && DL="curl"
[ -z "$DL" ] && have wget && DL="wget"
if [ -z "$DL" ] && ! have git; then
  die "Need curl, wget, or git. In Termux: pkg install curl git"
fi

# --- 4. Download the project -----------------------------------------------
say "Installing to: $APP_DIR"
mkdir -p "$INSTALL_PARENT" "$(dirname "$BIN_TARGET")"

fetch() {
  # fetch <url> <dest>
  if have curl; then curl -fL --retry 3 -o "$2" "$1"
  elif have wget; then wget -O "$2" "$1"
  else return 1; fi
}

if have git; then
  say "Cloning via git..."
  if [ -d "$APP_DIR/.git" ]; then
    ( cd "$APP_DIR" && git pull --ff-only ) || warn "git pull failed; keeping existing copy"
  else
    rm -rf "$APP_DIR"
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_GIT" "$APP_DIR" \
      || die "git clone failed. Check the repository URL / your network."
  fi
else
  say "Downloading archive..."
  TMP="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/al.$$")"; mkdir -p "$TMP"
  fetch "$REPO_TAR" "$TMP/src.tar.gz" || die "Download failed. Check REPO_USER in install.sh."
  # --- 5. Verify files where possible ---
  if ! tar -tzf "$TMP/src.tar.gz" >/dev/null 2>&1; then die "Downloaded archive is corrupt."; fi
  tar -xzf "$TMP/src.tar.gz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 1 -type d -name "${REPO_NAME}*" | head -1)"
  [ -n "$SRC" ] || die "Unexpected archive layout."
  rm -rf "$APP_DIR"; mkdir -p "$APP_DIR"
  cp -rf "$SRC"/. "$APP_DIR"/
  rm -rf "$TMP"
fi

[ -f "$APP_DIR/bin/android-linux" ] || die "Project files missing after download."

# --- 6. Install the android-linux command ----------------------------------
chmod +x "$APP_DIR/bin/android-linux" 2>/dev/null || true
ln -sf "$APP_DIR/bin/android-linux" "$BIN_TARGET"
ok "Installed command: $BIN_TARGET"

case ":$PATH:" in
  *":$(dirname "$BIN_TARGET"):"*) : ;;
  *) warn "Add $(dirname "$BIN_TARGET") to your PATH to use 'android-linux' directly." ;;
esac

# --- 7. Launch first-run wizard --------------------------------------------
ok "AndroidLinux installed."
if [ -t 0 ] && [ -t 1 ]; then
  say "Launching first-run setup..."
  exec "$BIN_TARGET" install
else
  say "Non-interactive shell detected. Run this in Termux to set up:"
  printf '    android-linux install\n'
fi
