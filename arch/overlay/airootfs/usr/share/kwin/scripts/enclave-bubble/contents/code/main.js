// Enclave Bubble — part 1 of the Enclave window standard (Plasma 6 / KWin).
//
// Strips native decorations from normal application windows, so the Enclave
// floating control bubble (part 2 — a layer-shell overlay, see
// arch/kwin-bubble.md) can own drag + minimize/maximize/close OS-wide,
// including on foreign (Wine/Waydroid/Flatpak) windows.
//
// NOT enabled by default yet: enabling frameless before the bubble overlay
// exists would leave windows with no close button. It is turned on (listed in
// kwinrc [Plugins] enclave-bubbleEnabled=true) once the overlay ships.

function strip(w) {
    if (!w) {
        return;
    }
    // Only ordinary, managed app windows — never panels, docks, the desktop,
    // OSDs, tooltips, etc.
    if (w.normalWindow === true && w.managed === true) {
        w.noBorder = true;
    }
}

workspace.windowList().forEach(strip);
workspace.windowAdded.connect(strip);
