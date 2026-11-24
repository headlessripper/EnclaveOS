#!/usr/bin/env bash
# Enclave OS — live session setup (oneshot, before the display manager).
# Creates the live user + password, passwordless sudo, and the en_US.UTF-8
# locale. Idempotent.
#
# Deliberately NOT using `set -e`: this service is boot-critical (SDDM autologs
# in as this user). If any single step failed under `set -e`, the whole service
# would fail and leave no account — which black-screens the login. Instead each
# step is best-effort and the account + password are created first, so the user
# always exists even if a later step hiccups. Always exits 0.
set -u

LIVE_USER="enclave"

# --- live user + password (the critical part — do this first, robustly) ---
if ! id -u "$LIVE_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$LIVE_USER" || useradd -M -s /bin/bash "$LIVE_USER" || true
fi
# Make sure a home exists even if -m was skipped.
[ -d "/home/$LIVE_USER" ] || { mkdir -p "/home/$LIVE_USER"; chown "$LIVE_USER:$LIVE_USER" "/home/$LIVE_USER" 2>/dev/null; }
echo "${LIVE_USER}:${LIVE_USER}" | chpasswd || \
  printf '%s\n%s\n' "$LIVE_USER" "$LIVE_USER" | passwd "$LIVE_USER" 2>/dev/null || true

# --- group membership (only groups that exist; never fatal) ---
for grp in wheel video audio storage power lp input network sys rfkill; do
  if getent group "$grp" >/dev/null 2>&1; then
    gpasswd -a "$LIVE_USER" "$grp" >/dev/null 2>&1 || true
  fi
done

# --- passwordless sudo (live medium convenience only) ---
install -d -m 0755 /etc/sudoers.d 2>/dev/null || mkdir -p /etc/sudoers.d
printf '%s\n' "${LIVE_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-enclave-live 2>/dev/null || true
chmod 0440 /etc/sudoers.d/10-enclave-live 2>/dev/null || true

# --- locale ---
if ! locale -a 2>/dev/null | grep -qiE 'en_US\.utf-?8'; then
  sed -i 's/^#\s*\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen 2>/dev/null || true
  locale-gen 2>/dev/null || true
fi

exit 0
