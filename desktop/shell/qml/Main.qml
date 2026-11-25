// Enclave Shell — the session's surfaces, wired together: the dock, the
// desktop (wallpaper, shortcuts, the search widget, the Now and other
// widgets), the bubble and the flyouts. There is no top bar: status lives in
// the Now widget and search in its own widget. Only one flyout (Start,
// Search, Control Center, calendar) is open at once.
import QtQuick
import Enclave

QtObject {
    id: shell

    property Status status: Status {}

    property Wallpaper wallpaper: Wallpaper {
        onControlCenterRequested: shell.toggle(shell.controlCenter)
        onWidgetsToggled: shell.toggleWidgets()
        onStatusToggled: shell.toggleStatus()
        onSearchWidgetToggled: shell.toggleSearchWidget()
        widgetsShown: shell.widgets.showCards
        statusShown: shell.widgets.showStatus
        searchShown: shell.searchWidget.visible
    }

    property Widgets widgets: Widgets {
        status: shell.status
        onCalendarRequested: shell.toggle(shell.calendar)
        onControlCenterRequested: shell.toggle(shell.controlCenter)
    }

    property SearchWidget searchWidget: SearchWidget {
        onSearchRequested: shell.open(shell.search)
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
    property Spotlight search: Spotlight {}
    property ControlCenter controlCenter: ControlCenter { status: shell.status }
    property CalendarPanel calendar: CalendarPanel {}

    property Bubble bubble: Bubble {
        onControlCenterRequested: shell.toggle(shell.controlCenter)
        // let the bubble fold away before the picture is taken
        onScreenshotRequested: System.run("sh", ["-c", "sleep 0.35; exec enclave-screenshot"])
    }

    readonly property var flyouts: [start, search, controlCenter, calendar]
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
        widgets.showCards = !widgets.showCards
        System.setSetting("desktop/widgets", widgets.showCards)
    }
    function toggleStatus() {
        widgets.showStatus = !widgets.showStatus
        System.setSetting("desktop/status", widgets.showStatus)
    }
    function toggleSearchWidget() {
        searchWidget.visible = !searchWidget.visible
        System.setSetting("desktop/search", searchWidget.visible)
    }
    // Display choices made in Settings ("displays/<output>" = "WxH@R scale"),
    // put back when the session starts.
    function applyDisplays() {
        for (const name of System.settingKeys("displays")) {
            const v = String(System.setting("displays/" + name, "")).split(" ")
            if (v.length < 2 || !/^\d+x\d+@[0-9.]+$/.test(v[0])) continue
            if (System.compositor === "hyprland")
                System.hypr("hl.monitor({ output = \"" + name + "\", mode = \"" + v[0] + "\", position = \"auto\", scale = " + Number(v[1]) + " })")
            else
                System.query("wlr-randr", ["--output", name, "--mode", v[0] + "Hz", "--scale", String(Number(v[1]))], () => {})
        }
    }
    Component.onCompleted: applyDisplays()

    // Commands from `enclave-shell --command NAME` (keyboard shortcuts, scripts).
    property Connections commands: Connections {
        target: System
        function onCommand(name) {
            switch (name) {
            case "start": shell.toggle(shell.start); break
            case "start-open": shell.open(shell.start); break
            case "search": shell.toggle(shell.search); break
            case "start-close": shell.start.close(); break
            case "all-apps": shell.closeAll(shell.start); shell.start.open("all"); break
            case "control-center": shell.toggle(shell.controlCenter); break
            case "calendar": shell.toggle(shell.calendar); break
            case "close-all": shell.closeAll(); break
            case "bubble": shell.closeAll(); shell.bubble.open = !shell.bubble.open; break
            case "widgets": shell.toggleWidgets(); break
            case "status-widget": shell.toggleStatus(); break
            case "search-widget": shell.toggleSearchWidget(); break
            case "show-desktop": Windows.minimizeAll(); break
            case "dock-peek": shell.dock.peekFirst(); break
            case "apply-displays": shell.applyDisplays(); break
            case "reload-settings":     // Enclave Settings changed shell.conf
                Theme.reload()
                shell.dock.reloadOptions()
                shell.widgets.showStatus = String(System.setting("desktop/status", true)) !== "false"
                shell.widgets.showCards = String(System.setting("desktop/widgets", true)) !== "false"
                shell.searchWidget.visible = String(System.setting("desktop/search", true)) !== "false"
                shell.wallpaper.custom = String(System.setting("desktop/wallpaper", ""))
                Apps.reload()
                break
            case "dock-menu": shell.dock.showMenu(); break
            case "maximize": Windows.activeToggleMaximize(); break
            case "minimize": Windows.activeMinimize(); break
            case "toggle-appearance": Theme.toggleDark(); break
            case "quit": Qt.quit(); break
            default: console.warn("enclave-shell: unknown command", name)
            }
        }
    }
}
