#!/usr/bin/env bash
# Wrapper around vagrant for the WRI lab project.
#
# Vagrant stores per-machine state, including the generated SSH private key,
# in the project's .vagrant directory. On NTFS/exFAT mounts chmod is a no-op,
# so Vagrant cannot secure that key and every command dies with an "invalid
# permissions" error. This wrapper detects such filesystems and points
# VAGRANT_DOTFILE_PATH at the home directory instead.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${VAGRANT_DOTFILE_PATH:-}" ]]; then
  probe="$repo_root/.perm-probe.$$"
  if touch "$probe" 2>/dev/null; then
    chmod 600 "$probe" 2>/dev/null || true
    if [[ "$(stat -c '%a' "$probe")" != "600" ]]; then
      export VAGRANT_DOTFILE_PATH="$HOME/.vagrant"
      printf '[lab] Project dir cannot hold SSH keys (NTFS/exFAT); using %s\n' \
        "$VAGRANT_DOTFILE_PATH" >&2
    fi
    rm -f "$probe"
  fi
fi

exec vagrant "$@"
