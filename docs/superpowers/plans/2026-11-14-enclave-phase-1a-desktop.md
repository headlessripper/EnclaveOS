# Enclave OS — Phase 1a: The Enclave Desktop (base) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the headless Enclave base into a polished, branded KDE Plasma 6 desktop that boots straight to a clean, uncluttered, Windows-like Enclave session — declaratively configured, reproducible, and bootable from a KVM-free image.

**Architecture:** A new `desktop.nix` module enables Plasma 6 (Wayland) + SDDM with autologin for the `enclave` user. All look-and-feel — dark theme + orange accent, wallpaper, a single clean bottom panel (start menu + task bar + tray + clock), fonts, and the Enclave icon theme — is declared with **plasma-manager** (via home-manager as a NixOS module), so the desktop is reproducible, not hand-configured on first boot. A graphical repart image (built without KVM, as in Phase 0) delivers it.

**Tech Stack:** NixOS 26.05, KDE Plasma 6, SDDM (Wayland), home-manager + plasma-manager, systemd-repart image, qemu-img (raw→vmdk).

**Spec:** `docs/superpowers/specs/2026-11-14-enclave-os-design.md` (Phase 1, §8 desktop/window-system, §9)

## Scope

- **In (1a):** Plasma 6 desktop, SDDM + autologin, Enclave dark/orange theme, wallpaper, clean bottom panel (Kickoff start menu, Icons-only task manager, system tray, digital clock), Enclave icon theme, Dolphin (files) + System Settings present, graphical bootable image.
- **Out (→ Phase 1b, separate plan):** the frameless-window + floating control-bubble standard (KWin script + widget) from design §8. It builds on this working desktop.

## Global Constraints

- **Base:** NixOS flakes, `x86_64-linux`, pinned nixpkgs `nixos-26.05` (already locked). home-manager + plasma-manager inputs track **release-26.05**, `inputs.nixpkgs.follows = "nixpkgs"`.
- **Session:** Plasma 6 on **Wayland** (design "lightweight but deadly"; Wayland is the modern default).
- **Identity stays:** `os-release NAME=Enclave` and existing branding (Phase 0) must remain intact.
- **Declarative:** no first-boot manual setup — panel/theme/icons come from plasma-manager, applied at home-manager activation.
- **Accent/brand:** dark UI with the icon's orange accent. Accent color `#FF6A13` (from `light-orange-dot`; adjustable). Base dark `#0B0E16`.
- **User:** autologin as `enclave` (dev default; Phase 0 user, password `enclave`).
- **Build result links on WSL ext4**, finished image copied to `dist/` (Phase 0 ruling).

## Review Focus

- **Autologin loop** — SDDM autologin misconfigured → login loops or drops to TTY. → Task 1 test asserts `services.displayManager.autoLogin.user = "enclave"` and Wayland session set; user boot-verifies the desktop appears.
- **plasma-manager config not applied** — home-manager activation didn't run for `enclave`, so the panel/theme are stock. → Task 2 asserts home-manager manages the `enclave` user; Task 4 user-verifies the single Enclave panel (not two stock panels).
- **Icon theme absent** — the Enclave icon package isn't a valid freedesktop icon theme, so it silently falls back. → Task 5 asserts the icon theme derivation has `index.theme` and is set as default.
- **Image too small / no graphics** — Plasma image exceeds the repart partition size or VM lacks video RAM. → Task 6 sizes the root partition for Plasma and documents VM settings (UEFI, ≥4 GB RAM, accelerate 3D off).
- **Wayland + VMware** — Plasma Wayland may need the `vmware`/`virtio` GPU path. → Task 1 includes the guest video drivers; Task 6 notes falling back to X11 session if Wayland won't start in VMware.

---

### Task 1: Desktop module — Plasma 6 + SDDM + autologin

**Files:**
- Create: `nixos/modules/desktop.nix`
- Modify: `nixos/configuration.nix` (import `./modules/desktop.nix`)
- Test: `tests/phase1-asserts.sh` (new; same `nix eval --json` style as `tests/phase0-asserts.sh`)

**Interfaces:**
- Consumes: Phase 0 `common.nix`/`base.nix` (user `enclave`, firmware).
- Produces: a graphical system. Sets `services.desktopManager.plasma6.enable = true`; `services.displayManager.sddm = { enable = true; wayland.enable = true; }`; `services.displayManager.autoLogin = { enable = true; user = "enclave"; }`; `services.displayManager.defaultSession = "plasma"`; guest video (`virtualisation.vmware.guest.enable` / `services.xserver.videoDrivers`), `environment.systemPackages` with `kdePackages.dolphin` and `kdePackages.systemsettings` (Plasma ships these, assert presence).

- [ ] **Step 1: Write the assertion test**

Add to `tests/phase1-asserts.sh` checks: `services.desktopManager.plasma6.enable == true`, `services.displayManager.sddm.enable == true`, `services.displayManager.autoLogin.user == "enclave"`, `services.displayManager.defaultSession == "plasma"`.

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/phase1-asserts.sh`
Expected: FAIL (plasma6 not enabled) before `desktop.nix`.

- [ ] **Step 3: Implement `nixos/modules/desktop.nix`** and import it in `configuration.nix`.

Set the options in Interfaces. Approach: keep it minimal; Plasma 6 pulls Dolphin/System Settings but assert them explicitly so the test is meaningful.

- [ ] **Step 4: Run tests + build toplevel**

Run: `bash tests/phase1-asserts.sh` then `nix build .#nixosConfigurations.enclave.config.system.build.toplevel`
Expected: asserts PASS; toplevel builds.

- [ ] **Step 5: Commit** (`feat: Plasma 6 desktop module (SDDM, Wayland, autologin)`)

---

### Task 2: home-manager + plasma-manager wiring

**Files:**
- Modify: `flake.nix` (add `home-manager`, `plasma-manager` inputs; pass to modules)
- Create: `nixos/modules/home.nix` (home-manager NixOS module + `home-manager.users.enclave`)
- Modify: `nixos/configuration.nix` (import home-manager module + `nixos/modules/home.nix`)

**Interfaces:**
- Consumes: Task 1 desktop; the `enclave` user.
- Produces: `home-manager.users.enclave` managed with plasma-manager's `programs.plasma` available; `home-manager.useGlobalPkgs = true; useUserPackages = true;`. Later tasks (3–5) add `programs.plasma.*` here.

- [ ] **Step 1: Write the test** — assert `home-manager.users.enclave` is set (eval `...config.home-manager.users.enclave.home.stateVersion`).
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Add inputs + `home.nix`.** Wire `inputs.home-manager.nixosModules.home-manager` and `inputs.plasma-manager.homeManagerModules.plasma-manager`. Set `home.stateVersion = "26.05"`.
- [ ] **Step 4: Build toplevel; assert passes.**
- [ ] **Step 5: Commit** (`feat: home-manager + plasma-manager integration for enclave user`)

---

### Task 3: Enclave theme — dark + orange, wallpaper, fonts

**Files:**
- Modify: `nixos/modules/home.nix` (`programs.plasma.workspace`, `programs.plasma.fonts`)
- Create: `nixos/pkgs/enclave-wallpaper.nix` (derivation rendering a dark wallpaper with the logo)

**Interfaces:**
- Consumes: Task 2 plasma-manager.
- Produces: `programs.plasma.workspace = { colorScheme/lookAndFeel = dark; wallpaper = <enclave-wallpaper>; }`, `programs.plasma.workspace.accentColor = "#FF6A13"`, a base font (e.g. Inter/Noto). `enclave-wallpaper` = a PNG built with `pkgs.imagemagick` compositing `assets/branding/light-orange-dot/1024x1024.png` centered on a `#0B0E16` 1920×1080 canvas.

- [ ] **Step 1: Write the test** — assert `programs.plasma.workspace.accentColor == "#FF6A13"` and wallpaper path is the enclave-wallpaper store path.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement the wallpaper derivation + workspace theme settings.**
- [ ] **Step 4: Build toplevel; assert passes.**
- [ ] **Step 5: Commit** (`feat: Enclave dark theme, orange accent, branded wallpaper`)

---

### Task 4: Clean bottom panel (start menu, taskbar, tray, clock)

**Files:**
- Modify: `nixos/modules/home.nix` (`programs.plasma.panels`)

**Interfaces:**
- Consumes: Task 2/3.
- Produces: exactly one `programs.plasma.panels` entry — bottom, with widgets in order: `org.kde.plasma.kickoff` (start menu, Enclave icon), `org.kde.plasma.icontasks` (task manager), `org.kde.plasma.marginsseparator`, `org.kde.plasma.systemtray`, `org.kde.plasma.digitalclock`. No second/top panel. Height ~44.

- [ ] **Step 1: Write the test** — assert the panels list has length 1 and location is "bottom" (eval the plasma-manager panels option or the generated config).
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement the single clean panel.** Set Kickoff's icon to the Enclave logo.
- [ ] **Step 4: Build toplevel; assert passes.**
- [ ] **Step 5: Commit** (`feat: single clean Enclave taskbar (start menu, tasks, tray, clock)`)

---

### Task 5: Enclave icon theme

**Files:**
- Create: `nixos/pkgs/enclave-icons.nix` (freedesktop icon theme packaging the icon pack)
- Modify: `nixos/modules/home.nix` (set `programs.plasma.workspace.iconTheme`)

**Interfaces:**
- Consumes: `assets/branding/light-orange-dot/*`.
- Produces: `enclave-icons` derivation with a valid `index.theme` (inherits `breeze-dark` for coverage, overrides the app/places logo icons with the Enclave mark at the standard sizes 16–512); `programs.plasma.workspace.iconTheme = "Enclave"`.

- [ ] **Step 1: Write the test** — assert the built `enclave-icons` path contains `share/icons/Enclave/index.theme`, and iconTheme is "Enclave".
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement the icon-theme derivation + set it.** Inherit breeze-dark so only the Enclave-branded icons override; wire the pack's PNG sizes into the theme's size dirs.
- [ ] **Step 4: Build toplevel; assert passes.**
- [ ] **Step 5: Commit** (`feat: Enclave icon theme`)

---

### Task 6: Graphical image + boot verification

**Files:**
- Modify: `nixos/image.nix` (import desktop/home modules; grow root partition for Plasma)
- Modify: `flake.nix` (ensure `diskimage` now includes the desktop)

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: a bootable graphical Enclave image; `dist/enclave-disk.vmdk` rebuilt.

- [ ] **Step 1:** Grow the repart root `SizeMinBytes`/image size for Plasma (≈12–16 GB virtual); import desktop + home modules into the image config.
- [ ] **Step 2: Build the image** — `nix build .#packages.x86_64-linux.diskimage --out-link /home/nateg/enclave-diskimage-result` (KVM-free). Expected: exit 0.
- [ ] **Step 3: Convert raw→vmdk** into `dist/enclave-disk.vmdk` (reuse `convert-image.sh`).
- [ ] **Step 4: User boot verification** — attach to a UEFI VM (≥4 GB RAM): boots to SDDM→autologin→the Enclave Plasma desktop, dark/orange theme, single bottom panel, Enclave wallpaper + icons. If Wayland won't start under VMware, switch `defaultSession` to the X11 Plasma session and rebuild.
- [ ] **Step 5: Commit** (`feat: graphical Enclave desktop image`)

---

## Phase 1a Done When
- `nix build` of the system + image succeeds and asserts pass (Tasks 1–5).
- The image boots in a UEFI VM straight to a **branded Enclave Plasma desktop**: dark + orange, Enclave wallpaper, one clean bottom panel with the Enclave start menu, Enclave icon theme — visibly "Enclave," not stock Plasma (Task 6).

Next: Phase 1b — the frameless-window + floating control-bubble standard (design §8), built on this desktop.
