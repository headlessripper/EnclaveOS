// Enclave Shell — the dock: one floating glass island, truly centred. Start,
// pinned apps, then (after a divider) any other running app, and All apps at
// the end. Icons magnify gently toward the pointer, bounce while an app is
// launching, and wear a dot when running (an orange bar = the window in front).
// Status and the clock live in the top bar.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: true
    color: "transparent"
    title: "Enclave Taskbar"
    height: Theme.taskbarHeight
    width: 1280

    property bool startOpen: false
    property string startPage: ""
    signal startRequested()
    signal allAppsRequested()
    signal interacted()

    readonly property int gap: 6
    readonly property int islandHeight: height - gap * 2
    readonly property int islandRadius: Theme.radius.large - 2

    LayerShell.Window.scope: "enclave-taskbar"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
                               | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: Theme.taskbarHeight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Pinned apps first (taskbar pins), then any other running app. Each
    // group holds that app's open windows.
    readonly property var groups: {
        const wins = Windows.windows
        const pins = Apps.taskbarPins
        const out = [], byId = {}
        for (const id of pins) {
            const a = Apps.app(id)
            if (!a.appId) continue
            const g = { appId: id, icon: a.icon, name: a.name, pinned: true, windows: [] }
            out.push(g); byId[id] = g
        }
        for (const w of wins) {
            const id = Apps.matchAppId(w.appId) || ("window:" + w.appId)
            let g = byId[id]
            if (!g) {
                const a = Apps.app(id)
                g = { appId: id, icon: a.icon || w.appId, name: a.name || w.title,
                      pinned: false, windows: [] }
                out.push(g); byId[id] = g
            }
            g.windows.push(w)
        }
        return out
    }
    readonly property var pinnedGroups: groups.filter(g => g.pinned)
    readonly property var otherGroups: groups.filter(g => !g.pinned)

    function clickGroup(g) {
        root.interacted()
        if (g.windows.length === 0) {
            Apps.launch(g.appId)
            return true
        }
        if (g.windows.length === 1) {
            Windows.toggleMinimize(g.windows[0].index)
            return false
        }
        // several windows: cycle through them
        let next = 0
        for (let i = 0; i < g.windows.length; ++i)
            if (g.windows[i].activated && !g.windows[i].minimized) next = (i + 1) % g.windows.length
        Windows.activate(g.windows[next].index)
        return false
    }

    // A taskbar app (pinned or running); shared by both dock repeaters.
    Component {
        id: taskDelegate
        DockItem {
            id: task
            required property var modelData
            height: root.islandHeight
            pointerX: dockHover.hovered ? dockHover.point.position.x : -1
            offsetX: dockRow.x
            icon: modelData.icon
            name: modelData.windows.length > 1 ? modelData.name + "  ·  " + modelData.windows.length + " windows"
                                               : modelData.name
            running: modelData.windows.length > 0
            active: modelData.windows.some(w => w.activated && !w.minimized)
            checked: taskMenu.visible
            onClicked: if (root.clickGroup(modelData)) launching = true
            onRightClicked: taskMenu.popup(task, 0, -taskMenu.implicitHeight - 8)

            EmberMenu {
                id: taskMenu
                MenuItem {
                    text: task.running ? "New window" : "Open"
                    enabled: !task.modelData.appId.startsWith("window:")
                    onTriggered: { Apps.launch(task.modelData.appId); if (!task.running) task.launching = true }
                }
                MenuSeparator {}
                MenuItem {
                    text: task.modelData.pinned ? "Unpin from dock" : "Keep in dock"
                    enabled: !task.modelData.appId.startsWith("window:")
                    onTriggered: Apps.pinTaskbar(task.modelData.appId, !task.modelData.pinned)
                }
                MenuItem {
                    readonly property bool onDesktop: Apps.desktopPins.indexOf(task.modelData.appId) >= 0
                    text: onDesktop ? "Remove from desktop" : "Add to desktop"
                    enabled: !task.modelData.appId.startsWith("window:")
                    onTriggered: Apps.pinDesktop(task.modelData.appId, !onDesktop)
                }
                MenuItem {
                    text: task.modelData.windows.length > 1 ? "Close all windows" : "Close window"
                    visible: task.running
                    height: visible ? implicitHeight : 0
                    onTriggered: task.modelData.windows.slice().reverse().forEach(w => Windows.close(w.index))
                }
            }
        }
    }

    // ---------------- the dock ----------------
    Item {
        id: dock
        height: root.islandHeight
        width: dockRow.width + 12
        y: root.gap
        x: (root.width - width) / 2
        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }

        Glass { anchors.fill: parent; radius: root.islandRadius }
        HoverHandler { id: dockHover }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 0

            DockItem {
                height: root.islandHeight
                pointerX: dockHover.hovered ? dockHover.point.position.x : -1
                offsetX: dockRow.x
                icon: "/usr/share/enclave/" + (Theme.dark ? "enclave-logo-dark.svg" : "enclave-logo.svg")
                name: "Start"
                iconSize: 34
                checked: root.startOpen && root.startPage !== "all"
                onClicked: root.startRequested()
            }

            Repeater {
                model: root.pinnedGroups
                delegate: taskDelegate
            }

            Item {
                visible: root.otherGroups.length > 0
                width: 17
                height: root.islandHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: 1; height: 34
                    color: Theme.c.border
                }
            }

            Repeater {
                model: root.otherGroups
                delegate: taskDelegate
            }

            Item {
                width: 17
                height: root.islandHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: 1; height: 34
                    color: Theme.c.border
                }
            }

            DockItem {
                height: root.islandHeight
                pointerX: dockHover.hovered ? dockHover.point.position.x : -1
                offsetX: dockRow.x
                icon: "view-app-grid-symbolic?color=" + encodeURIComponent(Theme.c.text)
                iconSize: 26
                name: "All apps"
                checked: root.startOpen && root.startPage === "all"
                onClicked: root.allAppsRequested()
            }
        }
    }
}
