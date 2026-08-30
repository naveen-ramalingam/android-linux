#!/usr/bin/env bash
# alpine.sh - Alpine Linux rootfs source (official dl-cdn.alpinelinux.org).
# Alpine publishes alpine-minirootfs tarballs with .sha256 sidecar files on a
# stable CDN path. Source after distro.sh.

# Latest patch release per supported minor series. Update when Alpine releases.
_alpine_version() {
  case "$DISTRO_SUITE" in
    3.20) printf '3.20.3' ;;
    3.19) printf '3.19.4' ;;
    *) printf '3.20.3' ;;
  esac
}

_alpine_file() {
  local ver arch
  ver=$(_alpine_version)
  arch=$(arch_for_distro alpine) || return 1
  printf 'alpine-minirootfs-%s-%s.tar.gz' "$ver" "$arch"
}

alpine_url() {
  local arch file
  arch=$(arch_for_distro alpine) || {
    error_report "Alpine has no rootfs for architecture $ARCH" \
      "Detected CPU architecture is unsupported by Alpine." \
      "Verify architecture detection with 'android-linux info'."
    return 1
  }
  file=$(_alpine_file) || return 1
  printf 'https://dl-cdn.alpinelinux.org/alpine/v%s/releases/%s/%s' \
    "$DISTRO_SUITE" "$arch" "$file"
}

alpine_sha256() {
  local url sha
  url=$(alpine_url) || { printf ''; return 0; }
  sha=$(fetch_to_stdout "${url}.sha256") || { printf ''; return 0; }
  printf '%s\n' "$sha" | awk '{print $1; exit}'
}
