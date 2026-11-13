#!/usr/bin/env bash
# Phase 0 config assertions. Run from the repo root in WSL with Nix available.
# Each check evaluates one NixOS option and compares its JSON value.
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

# Task 2 — base system
check firmware      "hardware.enableRedistributableFirmware" "true"
check systemd-boot  "boot.loader.systemd-boot.enable"        "true"
check hostname      "networking.hostName"                    '"enclave"'
check user          "users.users.enclave.isNormalUser"       "true"
check stateVersion  "system.stateVersion"                    '"26.05"'

exit $fail
