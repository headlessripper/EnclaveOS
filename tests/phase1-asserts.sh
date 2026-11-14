#!/usr/bin/env bash
# Phase 1a config assertions. Run from the repo root in WSL with Nix available.
set -uo pipefail
export NIX_CONFIG='experimental-features = nix-command flakes'
NIX="/nix/var/nix/profiles/default/bin/nix"
cfg=".#nixosConfigurations.enclave.config"
fail=0

check() { # name  option-path  expected-json
  local got
  got=$("$NIX" eval --json "$cfg.$2" 2>/dev/null || echo '<err>')
  if [ "$got" = "$3" ]; then
    echo "PASS $1 ($2 = $got)"
  else
    echo "FAIL $1 ($2 = $got, want $3)"
    fail=1
  fi
}

# Task 1 — desktop
check plasma6        "services.desktopManager.plasma6.enable"   "true"
check sddm           "services.displayManager.sddm.enable"      "true"
check sddm-wayland   "services.displayManager.sddm.wayland.enable" "true"
check autologin      "services.displayManager.autoLogin.user"   '"enclave"'
check defaultsession "services.displayManager.defaultSession"   '"plasma"'

exit $fail
