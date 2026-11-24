// Enclave Shell — the session's surfaces, wired together.
import QtQuick
import Enclave

QtObject {
    id: shell

    property Wallpaper wallpaper: Wallpaper {}

    property Taskbar taskbar: Taskbar {
        startOpen: shell.start.visible
        onStartRequested: shell.start.toggle()
        onInteracted: shell.start.close()
    }

    property StartMenu start: StartMenu {}

    property Bubble bubble: Bubble {}

    // Commands from `enclave-shell --command NAME` (the Super key, scripts).
    property Connections commands: Connections {
        target: System
        function onCommand(name) {
            switch (name) {
            case "start": shell.start.toggle(); break
            case "start-open": shell.start.open(); break
            case "start-close": shell.start.close(); break
            case "show-desktop": Windows.minimizeAll(); break
            case "toggle-appearance": Theme.toggleDark(); break
            case "quit": Qt.quit(); break
            default: console.warn("enclave-shell: unknown command", name)
            }
        }
    }
}
