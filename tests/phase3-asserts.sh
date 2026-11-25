#!/usr/bin/env bash
# Enclave OS — Phase 3 (advisory assistant + voice) static assertions. Runs anywhere.
# Run from the repo root:  bash tests/phase3-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }
parses() { if bash -n "$1"; then pass "$2 parses"; else bad "$2 parse"; fi; }

AIR="arch/overlay/airootfs"
BIN="$AIR/usr/local/bin"

# --- advisory boundary (the core of v2) ---
has "$AIR/etc/enclave/assistant.toml" 'advisory_only = true'  "config: advisory_only"
has "$AIR/etc/enclave/assistant.toml" 'system_actions = false' "config: no system actions"
has "$AIR/etc/enclave/assistant.toml" 'default = "local"'     "config: local-first provider"

# --- launchers ---
exists "$BIN/enclave-assistant"        "assistant launcher present"
exists "$BIN/enclave-voice"            "voice launcher present"
exists "$BIN/enclave-models"           "model manager present"
exists "$BIN/enclave-assistant-setup"  "assistant setup present"
parses "$BIN/enclave-assistant"        "assistant launcher"
parses "$BIN/enclave-voice"            "voice launcher"
parses "$BIN/enclave-models"           "model manager"
parses "$BIN/enclave-assistant-setup"  "assistant setup"

# --- integration ---
has "$AIR/usr/share/applications/enclave-assistant.desktop" 'Exec=enclave-assistant' "start-menu entry"
exists "$AIR/usr/lib/enclave/assistant/PLACEHOLDER"         "assistant app install dir"
has "$AIR/etc/enclave/assistant.toml" 'engine = "openvox"'  "voice: openvox engine"

# --- runtime deps present in the image ---
has "arch/overlay/packages.netinstall" '^python-pipx$'      "netinstall: python-pipx (openvox)"

exit $fail
