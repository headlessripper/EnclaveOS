#!/usr/bin/env bash
# Enclave — register the Flathub remote once, when the network is up.
set -euo pipefail
command -v flatpak >/dev/null 2>&1 || exit 0
marker=/var/lib/enclave/flathub.done
[ -e "$marker" ] && exit 0
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
install -d /var/lib/enclave
: > "$marker"
