# Enclave OS — Phase 0: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reproducible, branded NixOS flake that builds an "Enclave" live ISO, installs to a VMware VM, boots to a basic session, and can roll back a system change.

**Architecture:** A single flake defines `nixosConfigurations.enclave` from modular `.nix` files (base system, branding) plus an `iso` build target from the NixOS installation-CD module. Everything is declarative, so every `nixos-rebuild switch` creates a bootable generation that rollback reverts to. Builds run under Nix on WSL; the test target is a VMware UEFI VM.

**Tech Stack:** NixOS (flakes), Nix, systemd-boot (UEFI), Btrfs, Plymouth, WSL2, VMware.

**Spec:** `docs/superpowers/specs/2026-11-14-enclave-os-design.md` (Phase 0, §9)

## Global Constraints

- **Base:** NixOS with **flakes** enabled. Config is modular `.nix` files; no bare literals for host-identifying values.
- **Architecture:** `x86_64-linux` only (AMD + Intel).
- **Bootloader/FS:** systemd-boot on **UEFI**; **Btrfs** root with subvolumes (`@`, `@home`, `@nix`) on the installed system.
- **Branding:** OS name is exactly **`Enclave`** (`os-release` `NAME="Enclave"`); boot splash uses the provided icon pack `light-orange-dot` (source: `C:\Users\nateg\Desktop\light-orange-dot\`, SVG + PNGs).
- **Reproducibility:** two builds of the same revision must produce identical store paths.
- **Rollback:** every system build is a generation selectable at boot.
- **nixpkgs pin:** pin to the latest **stable** NixOS release at execution time (verify available ref with `nix flake show github:NixOS/nixpkgs` — example value `nixos-25.11`). Record the chosen ref in `flake.nix`.
- **Build host:** WSL2 (Linux) with Nix installed and `experimental-features = nix-command flakes`. The working tree lives on the **WSL ext4 filesystem** (e.g. `~/EnclaveOS`), **not** `/mnt/c/...` — NixOS builds need a case-sensitive FS, symlinks, and speed. The GitHub remote is `https://github.com/headlessripper/EnclaveOS.git`.
- **Flake purity gotcha:** flakes only see **git-tracked** files. Every new file must be `git add`ed before it is referenced in a build, or the build acts as if it does not exist.
- **Line endings:** LF.

## Review Focus

- **Untracked file silently ignored** — a new module not `git add`ed builds as if absent; the build "succeeds" with the old config. → Task 1 adds a check that the flake references a tracked-only tree; every task's commit step stages files before building.
- **Non-reproducible ISO** — timestamps/paths leak in and two builds differ. → Task 6 builds twice and diffs store paths.
- **UEFI-only boot assumption** — VM set to BIOS/CSM fails to boot systemd-boot. → Task 5 fixes the VM firmware to UEFI and verifies the boot entry.
- **Rollback to an unbootable generation** — the previous generation is missing from the boot menu after a change. → Task 7 verifies generation 1 is still listed and boots after switching to generation 2.
- **Missing firmware** — Nvidia/Wi-Fi hardware dead on first boot for lack of `linux-firmware`. → Task 2 enables redistributable firmware and the test asserts it in the built config.

---

### Task 0: Environment & repo setup

**Files:**
- Create: `~/EnclaveOS/` (WSL ext4), cloned from the GitHub remote.

**Interfaces:**
- Produces: a working tree on WSL with Nix + flakes ready; all later tasks run `nix` here.

- [ ] **Step 1: Verify Nix + flakes in WSL**

Run: `nix --version && nix flake --help >/dev/null && echo OK`
Expected: prints a version and `OK`. If Nix is missing, install it (Determinate/official installer) and enable `nix-command flakes`, then re-run.

- [ ] **Step 2: Clone the repo onto the WSL filesystem**

Run: `git clone https://github.com/headlessripper/EnclaveOS.git ~/EnclaveOS && cd ~/EnclaveOS`
Expected: empty repo cloned (warning about empty repo is fine).

- [ ] **Step 3: Copy the approved spec/plan into the tree and the icon pack into `assets/branding/`**

Run: copy this plan + the design doc into `docs/superpowers/`, and the `light-orange-dot` icon pack into `assets/branding/light-orange-dot/`.
Expected: files present; `git add -A` stages them.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: seed EnclaveOS repo with spec, plan, and branding assets"
```

---

### Task 1: Flake scaffold + module skeleton

**Files:**
- Create: `flake.nix`, `.gitignore`, `nixos/configuration.nix`, `nixos/modules/` (empty placeholders referenced below), `.editorconfig` (LF).
- Test: `nix flake check`

**Interfaces:**
- Produces: `nixosConfigurations.enclave` (system `x86_64-linux`) and a packages output `iso` (added in Task 4). Modules imported in order: `./modules/base.nix`, `./modules/branding.nix`.

- [ ] **Step 1: Write `flake.nix`**

```nix
{
  description = "Enclave OS";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; # verify/bump to latest stable
  outputs = { self, nixpkgs }: {
    nixosConfigurations.enclave = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./nixos/configuration.nix ];
    };
  };
}
```

`nixos/configuration.nix` imports `./modules/base.nix` and `./modules/branding.nix` (created in Tasks 2–3; create empty `{ ... }: {}` stubs now so the flake evaluates).

- [ ] **Step 2: Stage files, then verify the flake evaluates**

Run: `git add -A && nix flake check`
Expected: PASS (no eval errors). Note: without `git add`, flake sees nothing — this is the Review-Focus check in practice.

- [ ] **Step 3: Verify outputs exist**

Run: `nix flake show`
Expected: shows `nixosConfigurations.enclave`.

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock .gitignore .editorconfig nixos/
git commit -m "feat: flake scaffold with enclave nixosConfiguration"
```

---

### Task 2: Base system module

**Files:**
- Create: `nixos/modules/base.nix`
- Test: `nix build .#nixosConfigurations.enclave.config.system.build.toplevel`

**Interfaces:**
- Consumes: the flake's `enclave` config from Task 1.
- Produces: a buildable system `toplevel`. Sets: `boot.loader.systemd-boot.enable = true`; UEFI; Btrfs root with subvolumes `@`,`@home`,`@nix`; `networking.hostName` from a `let` binding; `time.timeZone`/`i18n`; a normal user `enclave` (wheel); `hardware.enableRedistributableFirmware = true`; `nixpkgs.hostPlatform = "x86_64-linux"`; `system.stateVersion` pinned to the chosen release.

- [ ] **Step 1: Write the config assertion test**

Create `tests/base-eval.nix` (or a flake check) asserting the built config has: `config.hardware.enableRedistributableFirmware == true`, `config.boot.loader.systemd-boot.enable == true`, and a user named `enclave`.

- [ ] **Step 2: Run it to verify it fails**

Run: `nix eval .#nixosConfigurations.enclave.config.hardware.enableRedistributableFirmware`
Expected: FAIL/`false` before `base.nix` is written.

- [ ] **Step 3: Implement `nixos/modules/base.nix`**

Set the options listed in Interfaces. Use filesystem entries for `/`, `/home`, `/nix` on Btrfs subvolumes and an ESP at `/boot`. Approach note: for the VM, device paths come from the installer step (Task 5); define them as labels (`LABEL=enclave-root`, `LABEL=ENCLAVE-ESP`) so the config is device-agnostic.

- [ ] **Step 4: Verify it builds and asserts pass**

Run: `git add -A && nix build .#nixosConfigurations.enclave.config.system.build.toplevel`
Expected: PASS, a `result` symlink appears; the Step-1 assertions hold.

- [ ] **Step 5: Commit**

```bash
git add nixos/modules/base.nix tests/
git commit -m "feat: base system module (systemd-boot, btrfs, firmware, enclave user)"
```

---

### Task 3: Enclave branding module

**Files:**
- Create: `nixos/modules/branding.nix`
- Uses: `assets/branding/light-orange-dot/`
- Test: inspect built `os-release`

**Interfaces:**
- Consumes: base config (Task 2).
- Produces: branded identity. Sets exact `os-release` fields via `system.nixos.distroName`/`distroId` or `environment.etc."os-release"` override: `NAME="Enclave"`, `PRETTY_NAME="Enclave"`, `ID=enclave`; a Plymouth boot theme built from the icon pack; `/etc/issue` banner.

- [ ] **Step 1: Write the test**

`nix build` the toplevel, then assert `result/etc/os-release` (via `grep 'NAME="Enclave"'`) matches.

- [ ] **Step 2: Run to verify it fails**

Run: `nix build .#nixosConfigurations.enclave.config.system.build.toplevel && grep 'NAME="Enclave"' result/etc/os-release`
Expected: FAIL (still shows NixOS) before `branding.nix`.

- [ ] **Step 3: Implement `nixos/modules/branding.nix`**

Set the distro name/id and os-release fields; enable `boot.plymouth` with a custom theme whose logo is the `512x512.png` (or SVG) from the icon pack. Approach note: package the Plymouth theme with `pkgs.runCommand` copying the asset in; reference it in `boot.plymouth.theme`.

- [ ] **Step 4: Verify it passes**

Run: `nix build .#nixosConfigurations.enclave.config.system.build.toplevel && grep 'NAME="Enclave"' result/etc/os-release`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add nixos/modules/branding.nix assets/branding/
git commit -m "feat: Enclave branding (os-release, plymouth splash, issue banner)"
```

---

### Task 4: Live installer ISO target

**Files:**
- Create: `nixos/iso.nix`
- Modify: `flake.nix` (add `packages.x86_64-linux.iso` and a `nixosConfigurations.enclave-iso`)
- Test: `nix build .#iso`

**Interfaces:**
- Consumes: base + branding modules; the NixOS `installation-cd-minimal` module (`modulesPath`).
- Produces: `packages.x86_64-linux.iso` → an `.iso` with volume label `ENCLAVE`. The ISO boots to a console session as `enclave` with branding applied.

- [ ] **Step 1: Write the test (build produces an ISO)**

A flake check / script asserting `nix build .#iso` yields `result/iso/*.iso` and the ISO label is `ENCLAVE`.

- [ ] **Step 2: Run to verify it fails**

Run: `nix build .#iso`
Expected: FAIL ("unknown output `iso`") before this task.

- [ ] **Step 3: Implement `nixos/iso.nix` and wire the flake output**

Import `(modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")` plus `base.nix` + `branding.nix`; set `isoImage.isoName`/`isoImage.volumeID = "ENCLAVE"`. Add `enclave-iso` to `nixosConfigurations` and expose `packages.x86_64-linux.iso = self.nixosConfigurations.enclave-iso.config.system.build.isoImage`.

- [ ] **Step 4: Verify it passes**

Run: `git add -A && nix build .#iso && ls result/iso/*.iso`
Expected: PASS; an `.iso` file exists; label check prints `ENCLAVE`.

- [ ] **Step 5: Commit**

```bash
git add nixos/iso.nix flake.nix
git commit -m "feat: branded Enclave live installer ISO target"
```

---

### Task 5: Boot the ISO in VMware and install to the VM

**Files:** none (manual VM verification with exact steps).

**Interfaces:**
- Consumes: `result/iso/*.iso` from Task 4.
- Produces: an installed, bootable Enclave VM used by Tasks 6–7.

- [ ] **Step 1: Create a VMware VM** — x86_64, **UEFI firmware** (not BIOS/CSM), 2+ vCPU, 8 GB RAM, 40 GB disk; attach the built ISO.

- [ ] **Step 2: Boot the ISO**
Expected: VM shows the Enclave Plymouth splash and reaches a console login as `enclave`.

- [ ] **Step 3: Partition + install** — GPT: ESP labeled `ENCLAVE-ESP` (FAT32), root labeled `enclave-root` (Btrfs with `@`,`@home`,`@nix`); then `nixos-install --flake /mnt/etc/enclave#enclave` after copying the repo in (or install over network from the flake).
Expected: install completes without error.

- [ ] **Step 4: Reboot into the installed system**
Run (in VM): `cat /etc/os-release | grep Enclave`
Expected: boots from disk to Enclave; prints `NAME="Enclave"`. This is the Phase-0 "boots to a basic session" criterion.

---

### Task 6: Reproducibility check

**Files:** none (verification).

- [ ] **Step 1: Build the system toplevel twice**

Run: `nix build .#nixosConfigurations.enclave.config.system.build.toplevel --rebuild --print-out-paths` twice (or build, record path, `nix store delete`, rebuild).
Expected: identical store path both times.

- [ ] **Step 2: Build the ISO twice and compare**

Run: build `.#iso` twice; compare the output store paths.
Expected: identical store paths → reproducible.

- [ ] **Step 3: Record the result** in `docs/superpowers/specs/` notes and commit.

```bash
git commit -am "docs: record Phase 0 reproducibility verification"
```

---

### Task 7: Rollback demonstration

**Files:**
- Modify (temporarily): `nixos/modules/base.nix` (add one package, e.g. `pkgs.htop`).

**Interfaces:**
- Consumes: the installed VM (Task 5).

- [ ] **Step 1: Confirm current generation**

Run (in VM): `nixos-rebuild list-generations` (or `ls -l /nix/var/nix/profiles/system-*-link`)
Expected: generation 1 present and booted.

- [ ] **Step 2: Make a change and switch**

Add `environment.systemPackages = [ pkgs.htop ];`, `git add -A`, then in VM: `nixos-rebuild switch --flake .#enclave`.
Expected: generation 2 created; `htop` now on PATH; the systemd-boot menu lists **both** generations.

- [ ] **Step 3: Roll back**

Run (in VM): `nixos-rebuild switch --rollback` (or select generation 1 at the boot menu and reboot).
Expected: back on generation 1; `htop` gone; system boots cleanly. Rollback proven.

- [ ] **Step 4: Revert the temporary change and commit the Phase-0 completion**

```bash
git checkout nixos/modules/base.nix
git commit --allow-empty -m "chore: Phase 0 foundation complete (ISO builds, installs, boots, rolls back)"
```

---

## Phase 0 Done When
- `nix build .#iso` produces a branded `ENCLAVE` ISO reproducibly (Tasks 4, 6).
- The ISO boots in a VMware UEFI VM and installs to disk, booting to an Enclave session (Task 5).
- A config change creates a new generation and `--rollback` returns to the previous bootable one (Task 7).

Next: Phase 1 — the Enclave desktop (KDE Plasma + the frameless/bubble window standard).
