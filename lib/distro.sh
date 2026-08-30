#!/usr/bin/env bash
# distro.sh - Distribution registry, rootfs download/verify/extract.
# Source after common.sh, architecture.sh. Distro-specific URL logic lives in
# debian.sh / ubuntu.sh / alpine.sh which this file sources.

# --- Registry ---------------------------------------------------------------
# distro_resolve: normalize $1 (or $DISTRO) into DISTRO_FN + DISTRO_DISPLAY.
distro_resolve() {
  local d="${1:-${DISTRO:-debian}}"
  case "$d" in
    debian)        DISTRO_FN="debian";  DISTRO_SUITE="trixie";  DISTRO_DISPLAY="Debian 13 (trixie)";  DISTRO_HAS_CHECKSUM=1 ;;
    debian-stable) DISTRO_FN="debian";  DISTRO_SUITE="bookworm";DISTRO_DISPLAY="Debian 12 (bookworm)"; DISTRO_HAS_CHECKSUM=1 ;;
    ubuntu)        DISTRO_FN="ubuntu";  DISTRO_SUITE="noble";   DISTRO_DISPLAY="Ubuntu 24.04 LTS";    DISTRO_HAS_CHECKSUM=1 ;;
    alpine)        DISTRO_FN="alpine";  DISTRO_SUITE="3.20";    DISTRO_DISPLAY="Alpine Linux 3.20";   DISTRO_HAS_CHECKSUM=1 ;;
    archarm)       DISTRO_FN="archarm"; DISTRO_SUITE="latest";  DISTRO_DISPLAY="Arch Linux ARM";      DISTRO_HAS_CHECKSUM=0 ;;
    *) log_error "Unknown distro: $d"; return 1 ;;
  esac
  export DISTRO_FN DISTRO_SUITE DISTRO_DISPLAY DISTRO_HAS_CHECKSUM
}

# distro_decoder: decompressor required for the selected distro's rootfs.
distro_decoder() {
  case "${DISTRO_FN:-debian}" in
    debian) printf 'xz' ;;     # LXC images are .tar.xz
    *)      printf 'gzip' ;;   # ubuntu/alpine/archarm are .tar.gz
  esac
}

# termux_pkg_for: map a required capability to its Termux package name.
termux_pkg_for() {
  case "$1" in
    xz)        printf 'xz-utils' ;;
    zstd)      printf 'zstd' ;;
    gzip)      printf 'gzip' ;;
    tar)       printf 'tar' ;;
    curl)      printf 'curl' ;;
    wget)      printf 'wget' ;;
    proot)     printf 'proot' ;;
    coreutils) printf 'coreutils' ;;
    *)         printf '' ;;
  esac
}

# ensure_dependencies: detect tools needed for the selected distro/mode and,
# inside Termux, install them via `pkg`.
#   - HARD deps (downloader, tar, decompressor, checksum) are required to
#     download/verify/extract; install aborts if one is missing and cannot be
#     installed.
#   - SOFT deps (proot) are only needed to enter the environment later; a
#     missing soft dep warns but does not block extraction.
ensure_dependencies() {
  local -a hard=() soft=()
  local cap pkg

  if ! have_cmd curl && ! have_cmd wget && ! have_cmd aria2c; then
    hard+=(curl)
  fi
  have_cmd tar || hard+=(tar)
  local dec; dec=$(distro_decoder)
  have_cmd "$dec" || hard+=("$dec")
  if ! have_cmd sha256sum && ! have_cmd shasum && ! have_cmd openssl; then
    hard+=(coreutils)
  fi
  if [ "${INSTALL_MODE:-}" = "proot" ] && ! have_cmd proot; then
    soft+=(proot)
  fi

  if [ ${#hard[@]} -eq 0 ] && [ ${#soft[@]} -eq 0 ]; then
    log_debug "All required dependencies present."
    return 0
  fi
  [ ${#hard[@]} -gt 0 ] && log_warn "Missing required tools: ${hard[*]}"
  [ ${#soft[@]} -gt 0 ] && log_warn "Missing tools (needed to enter the environment): ${soft[*]}"

  # Map capabilities -> Termux packages (dedup, drop unmapped ones).
  local -a pkgs=() p
  for cap in "${hard[@]:-}" "${soft[@]:-}"; do
    [ -n "$cap" ] || continue
    pkg=$(termux_pkg_for "$cap")
    [ -n "$pkg" ] || continue
    local dup=0
    for p in "${pkgs[@]:-}"; do [ "$p" = "$pkg" ] && dup=1; done
    [ "$dup" = 0 ] && pkgs+=("$pkg")
  done

  # Dry run: preview only. Never require or install tools in this mode.
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    if [ "${IS_TERMUX:-0}" = "1" ] && have_cmd pkg && [ ${#pkgs[@]} -gt 0 ]; then
      log_info "[dry-run] would install packages: ${pkgs[*]}"
    else
      log_info "[dry-run] missing tools - required: ${hard[*]:-none}, optional: ${soft[*]:-none}"
    fi
    return 0
  fi

  if [ "${IS_TERMUX:-0}" = "1" ] && have_cmd pkg && [ ${#pkgs[@]} -gt 0 ]; then
    if confirm "Install missing packages via pkg (${pkgs[*]})?" Y; then
      log_info "Running: pkg install ${pkgs[*]}"
      if pkg install -y "${pkgs[@]}"; then
        log_ok "Installed: ${pkgs[*]}"
        return 0
      fi
      if [ ${#hard[@]} -gt 0 ]; then
        error_report "pkg install failed for required tools: ${pkgs[*]}" \
          "The package manager returned an error." \
          "Run 'pkg update' then 'pkg install ${pkgs[*]}' manually and re-run."
        return 1
      fi
      log_warn "pkg install failed; continuing, but install the optional tools later."
      return 0
    fi
    if [ ${#hard[@]} -gt 0 ]; then
      log_error "Required tools are missing and automatic install was declined."
      return 1
    fi
    log_warn "Optional tools not installed; you may not be able to enter the environment yet."
    return 0
  fi

  # Not Termux: cannot auto-install.
  if [ ${#hard[@]} -gt 0 ]; then
    log_warn "Install these required tools with your package manager, then re-run: ${hard[*]}"
    return 1
  fi
  log_warn "Continuing, but install these to use the environment: ${soft[*]}"
  return 0
}

# --- HTTP helpers -----------------------------------------------------------
# fetch_to_stdout: print a URL body to stdout (for small index files).
fetch_to_stdout() {
  local url="$1"
  if have_cmd curl; then
    curl -fsSL --max-time 30 "$url" 2>/dev/null
  elif have_cmd wget; then
    wget -q -O - --timeout=30 "$url" 2>/dev/null
  else
    return 1
  fi
}

# fetch_file: download a URL to a file, with resume support.
# Usage: fetch_file <url> <dest>
fetch_file() {
  local url="$1" dest="$2"
  log_info "Downloading: $url"
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would download to $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")" 2>/dev/null || true
  if have_cmd aria2c; then
    aria2c -x4 -s4 --continue=true --allow-overwrite=true \
      -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url" && return 0
  fi
  if have_cmd curl; then
    curl -fL --retry 3 --continue-at - -o "$dest" "$url" && return 0
  fi
  if have_cmd wget; then
    wget -c -O "$dest" "$url" && return 0
  fi
  error_report "Download failed for $url" \
    "No working download tool (aria2c/curl/wget) or the network is down." \
    "Install curl inside Termux (pkg install curl) and check connectivity."
  return 1
}

# --- Checksums --------------------------------------------------------------
sha256_of() {
  local f="$1"
  if have_cmd sha256sum; then sha256sum "$f" 2>/dev/null | awk '{print $1}'
  elif have_cmd shasum; then shasum -a 256 "$f" 2>/dev/null | awk '{print $1}'
  elif have_cmd openssl; then openssl dgst -sha256 "$f" 2>/dev/null | awk '{print $NF}'
  else return 1; fi
}

# verify_sha256: compare a file against an expected hash. Fails closed when a
# checksum-expected distro cannot be verified, unless explicitly overridden.
verify_sha256() {
  local file="$1" expected="$2"
  local actual="" have_tool=1
  actual=$(sha256_of "$file") || have_tool=0

  if [ -n "$expected" ] && [ "$have_tool" = 1 ]; then
    if [ "$actual" = "$expected" ]; then
      log_ok "Checksum verified: $(basename "$file")"
      return 0
    fi
    error_report "Checksum mismatch for $(basename "$file")" \
      "Expected $expected but got $actual." \
      "Delete the file in downloads/ and retry, or check for a corrupted mirror."
    return 1
  fi

  # Verification is impossible (no expected hash, or no hash tool available).
  if [ "${DISTRO_HAS_CHECKSUM:-1}" = "1" ]; then
    if [ "$have_tool" = 0 ]; then
      log_warn "No SHA256 tool is available, so this download cannot be verified."
    else
      log_warn "A checksum for $(basename "$file") could not be obtained from the source."
    fi
    if confirm "Proceed WITHOUT verification (not recommended)?" N; then
      log_warn "Continuing with an UNVERIFIED download."
      return 0
    fi
    error_report "Refusing to use an unverified download" \
      "This distribution publishes checksums, but verification was not possible." \
      "Install a sha256 tool, check your network, then retry."
    return 1
  fi

  # Distro genuinely publishes no checksum (e.g. Arch Linux ARM).
  log_warn "No published checksum for $(basename "$file") - installing unverified."
  return 0
}

# --- Public API -------------------------------------------------------------
# distro_rootfs_url: echo the rootfs archive URL for the current distro/arch.
distro_rootfs_url() { "${DISTRO_FN}_url"; }
# distro_rootfs_sha256: echo expected sha256 (may be empty).
distro_rootfs_sha256() { "${DISTRO_FN}_sha256"; }
# distro_archive_name: echo the local filename for the archive (URL basename).
distro_archive_name() {
  local url; url=$(distro_rootfs_url) || return 1
  printf '%s' "${url##*/}"
}

archive_ext() {
  case "$1" in
    *.tar.xz) printf 'tar.xz' ;;
    *.tar.gz|*.tgz) printf 'tar.gz' ;;
    *.tar.zst) printf 'tar.zst' ;;
    *.tar) printf 'tar' ;;
    *) printf 'tar.gz' ;;
  esac
}

# distro_download: resolve + download the rootfs archive into downloads/.
# Sets DISTRO_ARCHIVE to the local path on success.
distro_download() {
  arch_for_distro "$DISTRO_FN" >/dev/null || {
    error_report "Architecture $ARCH not supported by $DISTRO_DISPLAY" \
      "This distro has no rootfs for the detected CPU architecture." \
      "Try Alpine (broad arch support) or choose a different distro."
    return 1
  }
  # Arch Linux ARM is served over HTTP with no published checksum; treat it as
  # untrusted and require explicit confirmation.
  if [ "${DISTRO_FN:-}" = "archarm" ]; then
    log_warn "Arch Linux ARM downloads use HTTP and CANNOT be checksum-verified."
    log_warn "A network attacker could substitute a malicious image."
    if ! confirm "Install Arch Linux ARM anyway (unverified)?" N; then
      log_info "Aborting Arch Linux ARM install."
      return 1
    fi
  fi
  local url name dest
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would resolve + download the $DISTRO_DISPLAY rootfs for $ARCH"
    DISTRO_ARCHIVE="${LINUX_BASE}/downloads/${DISTRO_FN}-${DISTRO_SUITE}-${ARCH}.rootfs"; export DISTRO_ARCHIVE
    return 0
  fi
  url=$(distro_rootfs_url) || return 1
  name=$(distro_archive_name) || return 1
  dest="${LINUX_BASE}/downloads/${name}"
  DISTRO_ARCHIVE="$dest"; export DISTRO_ARCHIVE
  state_set DOWNLOADING
  fetch_file "$url" "$dest" || return 1
  state_set DOWNLOADED
}

# distro_verify: verify the downloaded archive.
distro_verify() {
  [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ] && { log_info "[dry-run] skip verify"; return 0; }
  local expected; expected=$(distro_rootfs_sha256) || expected=""
  verify_sha256 "$DISTRO_ARCHIVE" "$expected" || return 1
  state_set VERIFIED
}

# distro_extract: extract the archive into LINUX_ROOT.
distro_extract() {
  local archive="${1:-$DISTRO_ARCHIVE}" rootfs="${2:-$LINUX_ROOT}"
  [ -n "$rootfs" ] || { log_error "distro_extract: no rootfs target"; return 1; }
  path_within "$rootfs" "$LINUX_BASE" || { log_error "rootfs outside base"; return 1; }
  if [ "${ANDROID_LINUX_DRY_RUN:-0}" = "1" ]; then
    log_info "[dry-run] would extract $archive -> $rootfs"
    return 0
  fi
  [ -f "$archive" ] || { log_error "Archive not found: $archive"; return 1; }

  # Security: reject archives containing ".." traversal or absolute paths.
  tar_is_safe "$archive" || { log_error "Refusing to extract an unsafe archive."; return 1; }

  # Clean any previous rootfs so a partially-extracted (interrupted) install is
  # not merged with this one, which could leave a corrupted hybrid filesystem.
  if [ -e "$rootfs" ]; then
    log_info "Cleaning previous rootfs before extraction..."
    safe_remove "$rootfs" "$LINUX_BASE" 1 || { log_error "Could not clean previous rootfs"; return 1; }
  fi
  mkdir -p "$rootfs" 2>/dev/null || true
  state_set EXTRACTING
  log_info "Extracting rootfs (this can take a while)..."

  # Use --numeric-owner only when tar supports it (GNU). Toybox/busybox may not.
  local taropts=""
  if tar --help 2>&1 | grep -q 'numeric-owner'; then
    taropts="--numeric-owner"
  fi
  # Under proot we relocate device-node/link creation; under root we can extract fully.
  local extractor="tar"
  if [ "${INSTALL_MODE:-}" = "proot" ] && have_cmd proot; then
    extractor="proot --link2symlink tar"
  fi

  # Extract the rootfs. tar's exit status is captured, not treated as
  # automatically fatal: on Android tar commonly exits 1 for harmless reasons
  # (device nodes, xattrs, SELinux) even when the filesystem extracted correctly;
  # success is verified below by checking the rootfs is usable.
  local rc=0 tmptar=""
  local use_su=0
  [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ] && use_su=1

  if [ "$use_su" = 1 ]; then
    # The extractor runs as root via `su -c`. Piping the decompressed stream into
    # `su -c tar` is unreliable - the stdin pipe closes and the decompressor dies
    # with SIGPIPE (exit 141). Decompress to a temporary plain-tar file first and
    # extract from that file, so no pipe crosses the su boundary.
    local dldir input
    dldir=$(dirname "$archive")
    input="$archive"
    case "$archive" in
      *.zst)
        tmptar="$dldir/.extract.$$.tar"
        zstd -dc "$archive" > "$tmptar" || { log_error "zstd decompression failed"; rm -f "$tmptar" 2>/dev/null; return 1; }
        input="$tmptar" ;;
      *.xz|*.txz)
        tmptar="$dldir/.extract.$$.tar"
        xz -dc "$archive" > "$tmptar" || { log_error "xz decompression failed"; rm -f "$tmptar" 2>/dev/null; return 1; }
        input="$tmptar" ;;
      *.gz|*.tgz)
        tmptar="$dldir/.extract.$$.tar"
        gzip -dc "$archive" > "$tmptar" || { log_error "gzip decompression failed"; rm -f "$tmptar" 2>/dev/null; return 1; }
        input="$tmptar" ;;
    esac
    # shellcheck disable=SC2086
    run_extract $extractor $taropts -x -C "$rootfs" -f "$input" || rc=$?
    [ -n "$tmptar" ] && rm -f "$tmptar" 2>/dev/null
  else
    case "$archive" in
      *.zst)
        # shellcheck disable=SC2086
        zstd -dc "$archive" | run_extract $extractor $taropts -x -C "$rootfs" -f - || rc=$? ;;
      *.xz|*.txz)
        # shellcheck disable=SC2086
        xz -dc "$archive" | run_extract $extractor $taropts -x -C "$rootfs" -f - || rc=$? ;;
      *.gz|*.tgz)
        # shellcheck disable=SC2086
        gzip -dc "$archive" | run_extract $extractor $taropts -x -C "$rootfs" -f - || rc=$? ;;
      *)
        # shellcheck disable=SC2086
        run_extract $extractor $taropts -x -C "$rootfs" -f "$archive" || rc=$? ;;
    esac
  fi

  if [ "$rc" -ge 2 ]; then
    error_report "Extraction failed (tar exit $rc)" \
      "The archive may be corrupt or the filesystem rejected the writes." \
      "Check free space, run 'android-linux doctor', then retry."
    return 1
  fi
  if [ "$rc" -eq 1 ]; then
    log_warn "tar reported minor issues (exit 1) - usually harmless on Android"
    log_warn "(device nodes, xattrs, or SELinux). Verifying the rootfs..."
  fi

  # The real success test: did we get a usable rootfs?
  if [ ! -e "$rootfs/bin/sh" ] && [ ! -e "$rootfs/bin/busybox" ]; then
    error_report "Extraction did not produce a usable rootfs (no /bin/sh)" \
      "The archive may be truncated/corrupt, or extraction was blocked (tar exit $rc)." \
      "Check free space and permissions, run 'android-linux doctor', then retry."
    return 1
  fi

  fs_init_rootfs_tree "$rootfs"
  state_set CONFIGURING
  log_ok "Rootfs extracted to $rootfs"
}

# run_extract: run the tar extractor with root when in chroot mode.
run_extract() {
  if [ "${INSTALL_MODE:-}" = "chroot" ] && [ "${ROOT_AVAILABLE:-0}" = "1" ]; then
    run_as_root "$@"
  else
    "$@"
  fi
}
