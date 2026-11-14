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

checkSet() { # name  option-path   -> passes when value is set (not null/err/empty)
  local got
  got=$("$NIX" eval --json "$cfg.$2" 2>/dev/null || echo '<err>')
  if [ "$got" != "<err>" ] && [ "$got" != "null" ] && [ -n "$got" ]; then
    echo "PASS $1 (set: $got)"
  else
    echo "FAIL $1 ($2 = $got)"
    fail=1
  fi
}

checkApply() { # name  option-path  apply-fn  expected-json
  local got
  got=$("$NIX" eval --json "$cfg.$2" --apply "$3" 2>/dev/null || echo '<err>')
  if [ "$got" = "$4" ]; then
    echo "PASS $1 ($got)"
  else
    echo "FAIL $1 ($got, want $4)"
    fail=1
  fi
}

# Task 1 — desktop
check plasma6        "services.desktopManager.plasma6.enable"   "true"
check sddm           "services.displayManager.sddm.enable"      "true"
check sddm-wayland   "services.displayManager.sddm.wayland.enable" "true"
check autologin      "services.displayManager.autoLogin.user"   '"enclave"'
check defaultsession "services.displayManager.defaultSession"   '"plasma"'

# Task 2 — home-manager + plasma-manager
check hm-user   "home-manager.users.enclave.home.stateVersion"       '"26.05"'
check hm-plasma "home-manager.users.enclave.programs.plasma.enable"  "true"

# Task 3 — theme
check    colorscheme "home-manager.users.enclave.programs.plasma.workspace.colorScheme" '"BreezeDark"'
checkSet wallpaper   "home-manager.users.enclave.programs.plasma.workspace.wallpaper"

# Task 4 — one clean bottom panel
checkApply panels-count  "home-manager.users.enclave.programs.plasma.panels" "builtins.length" "1"
checkApply panel-loc     "home-manager.users.enclave.programs.plasma.panels" "ps: (builtins.elemAt ps 0).location" '"bottom"'
checkApply panel-float   "home-manager.users.enclave.programs.plasma.panels" "ps: (builtins.elemAt ps 0).floating" "true"
checkApply panel-island  "home-manager.users.enclave.programs.plasma.panels" "ps: (builtins.elemAt ps 0).lengthMode" '"fit"'

# Task 5 — icon theme
check icontheme "home-manager.users.enclave.programs.plasma.workspace.iconTheme" '"Enclave"'

exit $fail
