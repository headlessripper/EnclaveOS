# The Enclave bubble — floating window controls

Enclave's signature touch: a small, always-on-top, draggable pill that carries
**minimize / maximize / close** for whatever app window is active, from anywhere
on screen. Windows keep their normal title bars too; the bubble is an extra,
always-in-reach control.

Implementation: `airootfs/usr/local/bin/enclave-bubble` (Python + GTK 3 +
libwnck), started from `~/.config/autostart/enclave-bubble.desktop`.

- **Never takes focus**, so the window it acts on stays the active one.
- **Acts only on app windows** (normal windows and dialogs) — never the desktop,
  the taskbar or itself; with nothing to act on, its buttons dim.
- **Hides when the active window is fullscreen** (video, games, slides).
- **Compositor-aware:** rounded and translucent while a compositor runs; a solid
  style otherwise (no black corners), switching live when picom starts.
- Window class `Enclave-bubble`, which picom's rules use to give it a 22px
  pill radius.

(History: the KDE Plasma version was a KWin script + overlay; it was retired
with Plasma. See git history before 7fecf6e.)
