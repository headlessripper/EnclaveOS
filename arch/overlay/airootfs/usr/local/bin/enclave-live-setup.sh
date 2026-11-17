#!/usr/bin/env bash
# Enclave OS — live session setup (oneshot, before the display manager).
# Creates the live user, enables passwordless sudo on the live medium, and
# makes sure the en_US.UTF-8 locale exists. Idempotent.
set -euo pipefail

LIVE_USER="enclave"

# --- live user ---
if ! id -u "$LIVE_USER" >/dev/null 2>&1; then
  useradd -m -G wheel,network,video,audio,storage,power,lp,input \
    -s /bin/bash "$LIVE_USER"
fi
echo "${LIVE_USER}:${LIVE_USER}" | chpasswd

# --- passwordless sudo (live medium convenience only) ---
install -d -m 0750 /etc/sudoers.d
printf '%s\n' "${LIVE_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-enclave-live
chown root:root /etc/sudoers.d/10-enclave-live
chmod 0440 /etc/sudoers.d/10-enclave-live

# --- locale ---
if ! locale -a 2>/dev/null | grep -qiE 'en_US\.utf-?8'; then
  sed -i 's/^#\s*\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen || true
  locale-gen || true
fi
