// Enclave Shell — the taskbar: Start + pinned/running apps truly centred
// (Windows 11), tray and clock on the right, show-desktop sliver at the edge.
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
    signal startRequested()
    signal interacted()

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

    function clickGroup(g) {
        root.interacted()
        if (g.windows.length === 0) {
            Apps.launch(g.appId)
            return
        }
        if (g.windows.length === 1) {
            Windows.toggleMinimize(g.windows[0].index)
            return
        }
        // several windows: cycle through them
        let next = 0
        for (let i = 0; i < g.windows.length; ++i)
            if (g.windows[i].activated && !g.windows[i].minimized) next = (i + 1) % g.windows.length
        Windows.activate(g.windows[next].index)
    }

    // Mica-like glass bar with a hairline on top.
    Rectangle {
        anchors.fill: parent
        color: Theme.c.glass
        Rectangle { width: parent.width; height: 1; color: Theme.c.border }
    }

    Row {
        id: centre
        anchors.centerIn: parent
        spacing: 4

        IconButton {
            id: startButton
            width: 44; height: 40
            iconSize: 24
            icon: "/usr/share/enclave/enclave-logo.svg"
            checked: root.startOpen
            tooltip: "Start"
            onClicked: root.startRequested()
        }

        Repeater {
            model: root.groups
            delegate: Item {
                id: task
                required property var modelData
                readonly property bool running: modelData.windows.length > 0
                readonly property bool active: modelData.windows.some(w => w.activated && !w.minimized)
                width: 44; height: 40

                IconButton {
                    anchors.fill: parent
                    iconSize: 24
                    icon: task.modelData.icon
                    checked: task.active
                    tooltip: task.modelData.name
                    onClicked: root.clickGroup(task.modelData)
                    onRightClicked: menu.popup()
                }

                // running / active indicator (orange = the window in front)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 3; radius: 1.5
                    width: task.active ? 16 : (task.running ? 6 : 0)
                    color: task.active ? Theme.c.accent : Theme.c.textSecondary
                    Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                }

                Menu {
                    id: menu
                    popupType: Popup.Window
                    MenuItem {
                        text: task.modelData.name
                        enabled: !task.modelData.appId.startsWith("window:")
                        onTriggered: Apps.launch(task.modelData.appId)
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: task.modelData.pinned ? "Unpin from taskbar" : "Pin to taskbar"
                        enabled: !task.modelData.appId.startsWith("window:")
                        onTriggered: Apps.pinTaskbar(task.modelData.appId, !task.modelData.pinned)
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
    }

    // ---- right side: appearance, clock, show desktop ----
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            iconSize: 16
            symbolic: true
            icon: Theme.dark ? "weather-clear-symbolic" : "weather-clear-night-symbolic"
            tooltip: Theme.dark ? "Switch to light" : "Switch to dark"
            onClicked: Theme.toggleDark()
        }

        Item {
            id: clock
            width: clockText.implicitWidth + 24
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            property date now: new Date()
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clock.now = new Date()
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.small
                color: clockMouse.containsMouse ? Theme.c.hover : "transparent"
            }
            Column {
                id: clockText
                anchors.centerIn: parent
                Text {
                    anchors.right: parent.right
                    text: Qt.formatTime(clock.now, "HH:mm")
                    color: Theme.c.text
                    font.pointSize: 9
                }
                Text {
                    anchors.right: parent.right
                    text: Qt.formatDate(clock.now, "dd/MM/yyyy")
                    color: Theme.c.text
                    font.pointSize: 9
                }
            }
            MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true }
        }

        // Windows-style "show desktop" sliver at the far edge.
        Item {
            width: 10
            height: root.height
            Rectangle {
                anchors.centerIn: parent
                width: 1; height: 20
                color: Theme.c.border
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.interacted(); Windows.minimizeAll() }
            }
        }
    }
}
