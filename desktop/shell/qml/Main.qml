// Enclave Shell — the session's surfaces, wired together: the top bar, the
// dock, the desktop (wallpaper, shortcuts, widgets), the bubble and the
// flyouts. Only one flyout (Start, Control Center, calendar) is open at once.
import QtQuick
import Enclave

QtObject {
    id: shell

    property Status status: Status {}

    property Wallpaper wallpaper: Wallpaper {
        onControlCenterRequested: shell.toggle(shell.controlCenter)
        onWidgetsToggled: shell.toggleWidgets()
    }

    property Widgets widgets: Widgets { status: shell.status }

    property TopBar topBar: TopBar {
        status: shell.status
        startOpen: shell.start.visible
        controlCenterOpen: shell.controlCenter.visible
        calendarOpen: shell.calendar.visible
        onStartRequested: shell.toggle(shell.start)
        onSearchRequested: shell.open(shell.start)
        onControlCenterRequested: shell.toggle(shell.controlCenter)
        onCalendarRequested: shell.toggle(shell.calendar)
    }

    property Taskbar dock: Taskbar {
        startOpen: shell.start.visible
        startPage: shell.start.page
        onStartRequested: shell.toggle(shell.start)
        onAllAppsRequested: {
            if (shell.start.visible && shell.start.page === "all") shell.start.close()
            else { shell.closeAll(shell.start); shell.start.open("all") }
        }
        onInteracted: shell.closeAll()
    }

    property StartMenu start: StartMenu {}
    property ControlCenter controlCenter: ControlCenter { status: shell.status }
    property CalendarPanel calendar: CalendarPanel {}

    property Bubble bubble: Bubble {
        onControlCenterRequested: shell.toggle(shell.controlCenter)
        // let the bubble fold away before the picture is taken
        onScreenshotRequested: System.run("sh", ["-c", "sleep 0.35; exec enclave-screenshot"])
    }

    readonly property var flyouts: [start, controlCenter, calendar]
    function closeAll(except) {
        for (const f of flyouts)
            if (f !== except) f.close()
    }
    function toggle(f) {
        closeAll(f)
        f.toggle()
    }
    function open(f) {
        closeAll(f)
        f.open()
    }
    function toggleWidgets() {
        widgets.visible = !widgets.visible
        System.setSetting("desktop/widgets", widgets.visible)
    }

    // Commands from `enclave-shell --command NAME` (keyboard shortcuts, scripts).
    property Connections commands: Connections {
        target: System
        function onCommand(name) {
            switch (name) {
            case "start": shell.toggle(shell.start); break
            case "start-open": case "search": shell.open(shell.start); break
            case "start-close": shell.start.close(); break
            case "all-apps": shell.closeAll(shell.start); shell.start.open("all"); break
            case "control-center": shell.toggle(shell.controlCenter); break
            case "calendar": shell.toggle(shell.calendar); break
            case "close-all": shell.closeAll(); break
            case "bubble": shell.closeAll(); shell.bubble.open = !shell.bubble.open; break
            case "widgets": shell.toggleWidgets(); break
            case "show-desktop": Windows.minimizeAll(); break
            case "toggle-appearance": Theme.toggleDark(); break
            case "quit": Qt.quit(); break
            default: console.warn("enclave-shell: unknown command", name)
            }
        }
    }
}
