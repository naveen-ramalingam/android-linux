#!/usr/bin/env bash
# generic.sh - Generic device profile.
# Profiles let device-specific quirks be layered on top of capability detection.
# The generic profile applies no workarounds; it exists so the loader always
# has something to source. Add profiles/devices/<codename>.sh only when a real
# device needs a documented workaround.

# profile_apply: hook called after detection. No-op for the generic profile.
profile_apply() {
  log_debug "profile: generic (no device-specific workarounds)"
}

# profile_load: source a device-specific profile if one exists for the codename.
profile_load() {
  local codename="${DEV_CODENAME:-}"
  local pdir="${APP_HOME}/profiles/devices"
  if [ -n "$codename" ] && [ -f "$pdir/${codename}.sh" ]; then
    log_debug "profile: loading device override $codename"
    # shellcheck disable=SC1090
    . "$pdir/${codename}.sh"
  fi
  profile_apply
}
