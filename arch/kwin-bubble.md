# Enclave window standard — the floating control bubble

The signature Enclave touch: every window is **frameless**, and a **floating,
always-on-top, draggable bubble** carries the window controls (drag, minimize,
maximize, close) plus window functions. OS-wide — native Enclave apps *and*
foreign (Wine / Waydroid / Flatpak) windows.

## Two parts

**Part 1 — frameless (done, shipped, off by default).**
`usr/share/kwin/scripts/enclave-bubble/` is a KWin script that sets
`noBorder = true` on normal windows. Shipped but **not enabled** in `kwinrc`
yet, because frameless *without* the bubble would leave no close button.

**Part 2 — the bubble overlay (the deep piece, in progress).**
A small always-on-top surface that tracks the active window and provides the
controls. This is the hard part on **Wayland**, where a client can't freely
place an overlay over arbitrary windows. Plan:

- Build it as a **`wlr-layer-shell` / Plasma `PlasmaShellSurface` overlay**
  (QML + a tiny helper), anchored and kept above, following the active window's
  geometry via KWin's scripting/DBus (`org.kde.KWin`) which reports the active
  window and its frame geometry.
- Controls call KWin actions: minimize / toggle-maximize / close
  (`window.closeWindow()`, `window.minimized`, `window.setMaximize`) over the
  KWin scripting DBus, or a companion KWin script that exposes them.
- Drag moves the active window (`workspace.slotWindowMove` equivalent / DBus).
- Native Enclave (Tauri) apps get the bubble by default via the `.enc` SDK; for
  foreign apps the KWin script (part 1) removes their chrome first.

## Turn-on checklist (when part 2 is ready)

1. Add to `arch/overlay/airootfs/etc/xdg/kwinrc`:
   ```
   [Plugins]
   enclave-bubbleEnabled=true
   ```
2. Autostart the bubble overlay for the session.
3. Flip the Breeze decoration to `BorderSize=None` (or keep, since frameless
   wins) and verify close/min/max all route through the bubble.

Until then, windows keep normal Breeze decorations so the desktop is fully
usable.
