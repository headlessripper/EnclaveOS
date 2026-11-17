#!/usr/bin/env bash
# Enclave — first-login setup, run once per user from the Plasma session.
# Applies the Enclave look-and-feel (which also builds the Windows-familiar
# taskbar layout), color scheme, and wallpaper. Idempotent via a marker.
set -euo pipefail

marker="${XDG_CONFIG_HOME:-$HOME/.config}/enclave-firstrun.done"
[ -e "$marker" ] && exit 0

plasma-apply-lookandfeel -a org.enclave.desktop || true
plasma-apply-colorscheme EnclaveLight || true
plasma-apply-wallpaperimage /usr/share/enclave/wallpapers/enclave-default.svg 2>/dev/null || true

mkdir -p "$(dirname "$marker")"
: > "$marker"
