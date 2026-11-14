# Phase 0 — Verification Record

**Date:** 2026-11-14
**Branch:** phase-0-foundation

## Reproducibility (Task 6)
- Command: `nix build .#iso --rebuild --no-link`
- Result: exit 0, `checking outputs of '…-enclave.iso.drv'` with no `differ`/hash
  mismatch → the Enclave ISO is **bit-for-bit reproducible**.
- System toplevel also builds deterministically from the pinned nixpkgs
  (nixos-26.05 @ ac588ef).

## Build outputs
- ISO: `enclave.iso`, ISO9660 volume label `ENCLAVE`, ~1.5 GB.
- Distributed copy for VMware: `dist/enclave.iso`.

## Known non-blocking warnings (deferred minors)
- `isoImage.isoBaseName` / `isoImage.isoName` are deprecated in 26.05 (renamed to
  `image.baseName` / `image.fileName`); current options still work.
- `boot.zfs.forceImportRoot` defaults to `true` (26.11 will default `false`); not
  using ZFS, so no impact — can be silenced later.

## Remaining (user-gated, need a VMware VM)
- Task 5: boot ISO + install to disk, confirm boots to installed Enclave.
- Task 7: rollback demonstration (generation switch + `--rollback`).
