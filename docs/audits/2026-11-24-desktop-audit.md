# Desktop audit — 2026-11-24 (ISO `enclave-0.1.0-alpha.10`)

Snapshot of the state *before* the desktop overhaul. Findings were verified
against the shipped image (ISO + `airootfs.sfs` opened with 7-Zip), not only the
repo. Not booted in a VM for this audit.

## Silently broken
1. **Start menu config never loads** — Whisker is panel plugin 2 but its config
   was `whiskermenu-1.rc`; Whisker 2.10 only reads `whiskermenu-<id>.rc` (legacy
   migration) or `$XDG_CONFIG_DIRS/xfce4/whiskermenu/defaults.rc`.
2. **Every Enclave script shipped 0644** — mkarchiso copies airootfs with
   `--no-preserve=mode` and only applies profiledef `file_permissions`, so the
   build's `chmod` was a no-op. Bubble never started; flathub service 203/EXEC;
   assistant / .exe / .apk launchers dead.
3. **Installed system likely unbootable** — `/boot` empty in the squashfs (kernel
   only at `usr/lib/modules/*/vmlinuz`) and live `archiso.conf` initcpio hooks
   carried into the install.

## Not Windows-like
4. Taskbar empty at login (running windows only, no pinned apps); centred
   between the left edge and the tray, not on the screen.
5. Start menu had 41 visible entries incl. lstopo, Software Token ×2, Vim,
   Winetricks, Xarchiver, About Xfce, Settings Editor, 15 settings panels,
   duplicate installers/Files/Terminal.
6. No web browser installed; "Web Browser"/"Mail Reader" entries open nothing.
7. Papirus icons + Adwaita cursor; Enclave icon theme inherited uninstalled `breeze`.
8. Centred titles, no app icon, translucent titlebars, dimmed inactive windows,
   12px radius on maximized windows and menus.
9. Bubble: no compositing check (black corners), acts on desktop window, stale `.pyc`.
10. All effects depend on picom (glx, software GL) with no fallback.
11. Noto Sans UI font.

## Boot / build
12. GRUB background references `/boot/grub/enclave-boot.png`, not on the ISO;
    UEFI x64 uses systemd-boot anyway. `beep on`, 15 s timeout.
13. Theme step silently skipped without git/sassc; Fluent cloned unpinned, output discarded.
14. Desktop installer launcher not executable → "untrusted launcher" prompt.
15. README / arch/README still describe KDE Plasma.
16. Tests are static greps only — nothing checks the real image.
