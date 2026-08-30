#!/usr/bin/env bash
# common.sh - Shared helpers for AndroidLinux.
# Provides: versioning, colors, logging, config, TTY detection, path safety,
# and safe command execution helpers.
#
# This file is meant to be sourced, never executed directly.

# --- Guard against double-sourcing -----------------------------------------
if [ -n "${ANDROID_LINUX_COMMON_LOADED:-}" ]; then
  # When sourced, `return` exits the source; when run directly, `return`
  # fails and `exit 0` takes over. Both paths are intentional.
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi
ANDROID_LINUX_COMMON_LOADED=1

# --- Version ----------------------------------------------------------------
ANDROID_LINUX_VERSION="1.2.3"
ANDROID_LINUX_NAME="AndroidLinux"

# --- Base directories -------------------------------------------------------
# APP_HOME is the location of the installed AndroidLinux scripts.
# It is set by bin/android-linux; provide a fallback for direct sourcing.
: "${APP_HOME:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)}"

# State/config/logs live under the user's home by default.
: "${ANDROID_LINUX_HOME:=${HOME:-/data/local/tmp}/.android-linux}"
: "${ANDROID_LINUX_CONFIG_DIR:=${XDG_CONFIG_HOME:-${HOME:-/data/local/tmp}/.config}/android-linux}"
: "${ANDROID_LINUX_CONFIG_FILE:=${ANDROID_LINUX_CONFIG_DIR}/config.conf}"
: "${ANDROID_LINUX_LOG_DIR:=${ANDROID_LINUX_HOME}/logs}"
: "${ANDROID_LINUX_LOG_FILE:=${ANDROID_LINUX_LOG_DIR}/android-linux.log}"

# --- Runtime flags (may be overridden by CLI) -------------------------------
: "${ANDROID_LINUX_DEBUG:=0}"
: "${ANDROID_LINUX_NONINTERACTIVE:=0}"
: "${ANDROID_LINUX_DRY_RUN:=0}"
: "${ANDROID_LINUX_ASSUME_YES:=0}"

# --- Color support ----------------------------------------------------------
# Colors only when stdout is a TTY and the terminal claims color support.
al_supports_color() {
  [ -t 1 ] || return 1
  [ "${NO_COLOR:-}" = "" ] || return 1
  case "${TERM:-}" in
    ""|dumb) return 1 ;;
  esac
  return 0
}

if al_supports_color; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""
  C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# --- Logging ----------------------------------------------------------------
_al_ensure_logdir() {
  [ -d "$ANDROID_LINUX_LOG_DIR" ] || mkdir -p "$ANDROID_LINUX_LOG_DIR" 2>/dev/null || true
}

_al_log_to_file() {
  # $1=level $2=message
  _al_ensure_logdir
  [ -d "$ANDROID_LINUX_LOG_DIR" ] || return 0
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')" "$1" "$2" \
    >>"$ANDROID_LINUX_LOG_FILE" 2>/dev/null || true
}

log_info()  { printf '%s[*]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; _al_log_to_file INFO  "$*"; }
log_ok()    { printf '%s[+]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; _al_log_to_file INFO  "$*"; }
log_warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; _al_log_to_file WARN "$*"; }
log_error() { printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; _al_log_to_file ERROR "$*"; }
log_debug() {
  [ "${ANDROID_LINUX_DEBUG:-0}" = "1" ] && printf '%s[debug]%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
  _al_log_to_file DEBUG "$*"
}

# Structured error with cause + suggested fix.
error_report() {
  # $1=what  $2=why  $3=fix
  log_error "$1"
  [ -n "${2:-}" ] && printf '    %sReason:%s %s\n' "$C_DIM" "$C_RESET" "$2" >&2
  [ -n "${3:-}" ] && printf '    %sTry:%s %s\n' "$C_DIM" "$C_RESET" "$3" >&2
  printf '    %sLog:%s %s\n' "$C_DIM" "$C_RESET" "$ANDROID_LINUX_LOG_FILE" >&2
}

die() { log_error "$*"; exit 1; }

# --- Command helpers --------------------------------------------------------
# have_cmd: true if command exists in PATH.
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# try: run a command, never abort the script on failure. Returns exit code.
# Useful for optional detection under `set -e`.
try() {
  if "$@"; then return 0; fi
  local rc=$?
  log_debug "try: '$*' exited $rc"
  return "$rc"
}

# safe_get: capture stdout of a command, empty string on failure.
safe_get() {
  local out
  out=$("$@" 2>/dev/null) || out=""
  printf '%s' "$out"
}

# first_cmd: echo the first available command name from arguments.
first_cmd() {
  local c
  for c in "$@"; do
    if have_cmd "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

# shell_quote: POSIX-safe single-quote a string for re-parsing by a shell.
# Prevents command injection when building `su -c` / `sh -c` command strings.
shell_quote() {
  local s="$1" q="'"
  s=${s//$q/$q\\$q$q}
  printf '%s%s%s' "$q" "$s" "$q"
}

# real_path: resolve a path to its physical location (follows symlinks).
# Falls back to lexical normalization when readlink is unavailable or fails.
real_path() {
  local p="$1" r
  if have_cmd readlink; then
    r=$(readlink -f "$p" 2>/dev/null)
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  fi
  normalize_path "$p"
}

# --- Input validators -------------------------------------------------------
# validate_port: true if $1 is a valid TCP port number.
validate_port() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
}

# validate_name: true if $1 is a safe POSIX-style username (no metacharacters).
validate_name() {
  local n="${1:-}"
  [ -n "$n" ] || return 1
  [ "${#n}" -le 32 ] || return 1
  case "$n" in [a-z_]*) : ;; *) return 1 ;; esac
  case "$n" in *[!a-z0-9_-]*) return 1 ;; esac
  return 0
}

# --- Archive safety ---------------------------------------------------------
# decompressor_available: echo the command needed to read <archive>, or "" if
# none is required. Returns 1 if the needed decompressor is missing.
archive_decompressor() {
  local archive="$1"
  case "$archive" in
    *.zst)        printf 'zstd' ;;
    *.xz|*.txz)   printf 'xz' ;;
    *.gz|*.tgz)   printf 'gzip' ;;
    *.bz2)        printf 'bzip2' ;;
    *)            printf '' ;;
  esac
}

# decompressor_ready: true if the decompressor required by <archive> is present.
# Prints an actionable hint when it is missing.
decompressor_ready() {
  local archive="$1" tool
  tool=$(archive_decompressor "$archive")
  [ -n "$tool" ] || return 0
  if have_cmd "$tool"; then return 0; fi
  case "$tool" in
    xz)   log_error "'xz' is required for $(basename "$archive"). In Termux: pkg install xz-utils" ;;
    zstd) log_error "'zstd' is required for $(basename "$archive"). In Termux: pkg install zstd" ;;
    gzip) log_error "'gzip' is required for $(basename "$archive")." ;;
    bzip2) log_error "'bzip2' is required for $(basename "$archive"). In Termux: pkg install bzip2" ;;
  esac
  return 1
}

# tar_list: list members of an archive using an explicit decompressor pipeline,
# so listing succeeds exactly when extraction can.
tar_list() {
  local archive="$1"
  case "$archive" in
    *.zst) zstd -dc "$archive" 2>/dev/null | tar -tf - 2>/dev/null ;;
    *.xz|*.txz) xz -dc "$archive" 2>/dev/null | tar -tf - 2>/dev/null ;;
    *.gz|*.tgz) gzip -dc "$archive" 2>/dev/null | tar -tf - 2>/dev/null ;;
    *.bz2) bzip2 -dc "$archive" 2>/dev/null | tar -tf - 2>/dev/null ;;
    *) tar -tf "$archive" 2>/dev/null ;;
  esac
}

# tar_is_safe: reject archives containing absolute paths or ".." traversal.
# Fail-closed: if members cannot be listed, the archive is treated as unsafe.
tar_is_safe() {
  local archive="$1" listing bad
  # First confirm the decompressor exists, so a missing tool is reported as a
  # clear, fixable problem rather than "corrupt/unsafe".
  decompressor_ready "$archive" || return 1
  listing=$(tar_list "$archive") || {
    log_error "Cannot list archive members (corrupt or unsupported format): $(basename "$archive")"
    return 1
  }
  bad=$(printf '%s\n' "$listing" | grep -E '(^/|(^|/)\.\.(/|$))' | head -5)
  if [ -n "$bad" ]; then
    log_error "Archive contains unsafe member paths (absolute or '..'):"
    printf '%s\n' "$bad" | sed 's/^/    /' >&2
    return 1
  fi
  return 0
}

# --- TTY / interactivity ----------------------------------------------------
is_tty() { [ -t 0 ] && [ -t 1 ]; }

is_interactive() {
  [ "${ANDROID_LINUX_NONINTERACTIVE:-0}" = "1" ] && return 1
  is_tty
}

# --- Prompts (respect --yes / non-interactive) ------------------------------
# confirm "Question" [default:Y|N]  -> returns 0 for yes, 1 for no
confirm() {
  local prompt="$1" def="${2:-Y}" reply
  if [ "${ANDROID_LINUX_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  if ! is_interactive; then
    # Non-interactive without --yes: default to the safe answer.
    [ "$def" = "Y" ] && return 0 || return 1
  fi
  local hint="[Y/n]"
  [ "$def" = "N" ] && hint="[y/N]"
  printf '%s %s ' "$prompt" "$hint" >&2
  IFS= read -r reply || reply=""
  reply=${reply:-$def}
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ask "Prompt" "default" -> echoes answer
ask() {
  local prompt="$1" def="${2:-}" reply
  if ! is_interactive; then printf '%s' "$def"; return 0; fi
  if [ -n "$def" ]; then
    printf '%s [%s]: ' "$prompt" "$def" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r reply || reply=""
  printf '%s' "${reply:-$def}"
}

# ask_secret "Prompt" -> echoes password without terminal echo
ask_secret() {
  local prompt="$1" reply
  if ! is_interactive; then printf ''; return 0; fi
  printf '%s: ' "$prompt" >&2
  stty -echo 2>/dev/null || true
  IFS= read -r reply || reply=""
  stty echo 2>/dev/null || true
  printf '\n' >&2
  printf '%s' "$reply"
}

# --- UI helpers -------------------------------------------------------------
hr() { printf '%s\n' "=================================================="; }

banner() {
  printf '%s\n' "=================================================="
  printf '%s%s%s\n' "$C_BOLD" "$ANDROID_LINUX_NAME" "$C_RESET"
  printf '%s\n' "=================================================="
}

# --- Path safety ------------------------------------------------------------
# Exact-match forbidden: the path itself must never be touched.
# (/data children are allowed on purpose: Termux and $HOME live under /data,
# and rooted installs use /data/local/android-linux.)
AL_FORBIDDEN_EXACT="/ /data /storage /sdcard /proc /sys /dev /etc /root /home /usr /bin /sbin /var /mnt /boot"
# Tree forbidden: the path and EVERYTHING under it is protected. Limited to
# partitions that can never host an AndroidLinux installation.
AL_FORBIDDEN_TREE="/ /system /vendor /product /proc /sys /dev /etc"

# normalize_path: resolve to an absolute path without requiring existence.
normalize_path() {
  local p="$1"
  case "$p" in
    /*) : ;;
    "") return 1 ;;
    *) p="$PWD/$p" ;;
  esac
  # Collapse via awk-free pure-bash: use a simple loop.
  local out="/" seg IFS='/'
  # shellcheck disable=SC2086
  set -- $p
  local parts=() ; for seg in "$@"; do parts+=("$seg"); done
  local resolved=()
  for seg in "${parts[@]}"; do
    case "$seg" in
      ""|".") continue ;;
      "..") [ ${#resolved[@]} -gt 0 ] && unset 'resolved[${#resolved[@]}-1]' ;;
      *) resolved+=("$seg") ;;
    esac
  done
  if [ ${#resolved[@]} -eq 0 ]; then
    printf '/'
  else
    out=""
    for seg in "${resolved[@]}"; do out="$out/$seg"; done
    printf '%s' "$out"
  fi
}

# is_forbidden_path: true if the path is a protected system location.
# Rejects exact matches of the exact list, and anything inside a tree root.
is_forbidden_path() {
  local target; target=$(normalize_path "$1") || return 0
  local f
  for f in $AL_FORBIDDEN_EXACT; do
    [ "$target" = "$f" ] && return 0
  done
  for f in $AL_FORBIDDEN_TREE; do
    [ "$target" = "$f" ] && return 0
    case "$target/" in
      "$f/"*) return 0 ;;
    esac
  done
  return 1
}

# path_within: true if $1 is inside base $2 (or equal to it).
path_within() {
  local p b
  p=$(normalize_path "$1") || return 1
  b=$(normalize_path "$2") || return 1
  case "$p/" in
    "$b/"*) return 0 ;;
  esac
  return 1
}

# safe_remove: only removes a path that lives inside the AndroidLinux base.
# Usage: safe_remove <path> [<allowed_base>] [<use_root:0|1>]
# When <use_root> is 1 and root is available, the removal is done through
# run_as_root. This matters because a rootfs extracted in chroot mode is
# root-owned, so a non-root shell cannot delete it (Permission denied).
safe_remove() {
  local target="$1"
  local base="${2:-${LINUX_BASE:-$ANDROID_LINUX_HOME}}"
  local use_root="${3:-0}"
  local norm; norm=$(normalize_path "$target") || { log_error "safe_remove: invalid path '$target'"; return 1; }

  if [ -z "$norm" ] || [ "$norm" = "/" ]; then
    log_error "safe_remove: refusing to operate on '/'"
    return 1
  fi
  if is_forbidden_path "$norm"; then
    log_error "safe_remove: refusing to remove protected path '$norm'"
    return 1
  fi
  if ! path_within "$norm" "$base"; then
    log_error "safe_remove: '$norm' is outside the AndroidLinux base '$base' - refusing"
    return 1
  fi
  # Resolve symlinks and re-check, so a link inside the base cannot point at a
  # protected location (symlink escape).
  local rtarget rbase
  rtarget=$(real_path "$norm")
  rbase=$(real_path "$base")
  if [ -n "$rtarget" ] && [ -n "$rbase" ]; then
    if is_forbidden_path "$rtarget"; then
      log_error "safe_remove: resolved target '$rtarget' is a protected path - refusing"
      return 1
    fi
    case "$rtarget/" in
      "$rbase/"*) : ;;
      *)
        log_error "safe_remove: resolved target '$rtarget' escapes base '$rbase' - refusing"
        return 1 ;;
    esac
  fi
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would remove: $norm"
    return 0
  fi
  log_debug "safe_remove: rm -rf '$norm' (use_root=$use_root)"
  if rm -rf -- "$norm" 2>/dev/null; then
    return 0
  fi
  # Removal as the current user failed. The tree may be root-owned (extracted in
  # chroot mode). Escalate to root if allowed.
  if [ "$use_root" = "1" ]; then
    if [ -z "${ROOT_AVAILABLE:-}" ] && command -v detect_root >/dev/null 2>&1; then
      detect_root
    fi
    if [ "${ROOT_AVAILABLE:-0}" = "1" ] && command -v run_as_root >/dev/null 2>&1; then
      log_info "Retrying removal with root privileges..."
      run_as_root rm -rf -- "$norm"
      return $?
    fi
  fi
  log_error "safe_remove: could not remove '$norm' (permission denied?)"
  return 1
}

# --- Config -----------------------------------------------------------------
# Config keys are simple KEY=VALUE lines. Values are read into shell variables.
AL_CONFIG_KEYS="LINUX_BASE LINUX_ROOT DISTRO INSTALL_MODE SSH_PORT DESKTOP VNC_PORT VNC_LOCALHOST AUTO_START DNS BACKUP_DIR LINUX_USER PROOT_BIND_STORAGE"

config_load() {
  [ -f "$ANDROID_LINUX_CONFIG_FILE" ] || return 0
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    # Strip surrounding quotes.
    val=${val#\"}; val=${val%\"}
    case " $AL_CONFIG_KEYS " in
      *" $key "*) printf -v "$key" '%s' "$val" ;;
      *) log_debug "config_load: ignoring unknown key '$key'" ;;
    esac
  done <"$ANDROID_LINUX_CONFIG_FILE"
  log_debug "config loaded from $ANDROID_LINUX_CONFIG_FILE"
}

config_save() {
  mkdir -p "$ANDROID_LINUX_CONFIG_DIR" 2>/dev/null || {
    log_error "Cannot create config directory: $ANDROID_LINUX_CONFIG_DIR"; return 1; }
  local tmp="${ANDROID_LINUX_CONFIG_FILE}.tmp.$$"
  {
    printf '# AndroidLinux configuration\n'
    printf '# Generated %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"
    local key
    for key in $AL_CONFIG_KEYS; do
      printf '%s=%s\n' "$key" "${!key:-}"
    done
  } >"$tmp" && mv -f "$tmp" "$ANDROID_LINUX_CONFIG_FILE"
  log_debug "config saved to $ANDROID_LINUX_CONFIG_FILE"
}

config_get() { printf '%s' "${!1:-}"; }
config_set() { printf -v "$1" '%s' "$2"; }

# --- State machine ----------------------------------------------------------
# Installation state persisted for resume support.
state_file() { printf '%s' "${LINUX_BASE:-$ANDROID_LINUX_HOME}/.state"; }

state_set() {
  [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ] && { log_debug "[dry-run] skip state write"; return 0; }
  local sf; sf=$(state_file)
  mkdir -p "$(dirname "$sf")" 2>/dev/null || return 0
  printf '%s\n' "$1" >"$sf" 2>/dev/null || true
  log_debug "state -> $1"
}

state_get() {
  local sf; sf=$(state_file)
  [ -f "$sf" ] && cat "$sf" 2>/dev/null || printf ''
}

# --- Misc utilities ---------------------------------------------------------
# human_bytes: convert a byte count to a human-readable string.
human_bytes() {
  local b="${1:-0}" u=0
  local -a units=(B KB MB GB TB)
  while [ "$b" -ge 1024 ] 2>/dev/null && [ "$u" -lt 4 ]; do
    b=$((b / 1024)); u=$((u + 1))
  done
  printf '%s %s' "$b" "${units[$u]}"
}

# require_bash: abort if not running under bash.
require_bash() {
  if [ -z "${BASH_VERSION:-}" ]; then
    printf 'AndroidLinux requires bash. Please run with bash.\n' >&2
    exit 1
  fi
}
