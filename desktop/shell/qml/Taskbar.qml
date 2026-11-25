// Enclave Shell — the dock: one floating glass island, truly centred. Start,
// pinned apps, then (after a divider) any other running app, All apps and the
// Trash at the end.
//  · A pinned app's windows always gather under its pinned icon — never a
//    second icon. One dot per window (up to three); an ember bar marks the app
//    in front.
//  · Hover an open app for its window list (click a row to raise it, × to
//    close it). Scroll over an icon to step through its windows; middle-click
//    opens a new window.
//  · Drag pinned icons sideways to reorder them.
//  · Right-click the dock itself for its options: magnification, icon size,
//    auto-hide and the Trash. Only the island takes input; the rest of the
//    strip lets clicks through.
import QtQml
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

    // dock options (right-click the dock)
    property bool magnify: true
    property bool autoHide: false
    property bool showTrash: true
    property int iconSize: 40
    // (re)read from shell.conf: at start, and when Settings changes them
    function reloadOptions() {
        magnify = String(System.setting("dock/magnify", true)) !== "false"
        autoHide = String(System.setting("dock/autohide", false)) === "true"
        showTrash = String(System.setting("dock/trash", true)) !== "false"
        iconSize = Number(System.setting("dock/iconSize", 40)) || 40
    }
    function setOption(key, value) {
        root[key] = value
        System.setSetting("dock/" + ({ magnify: "magnify", autoHide: "autohide", showTrash: "trash", iconSize: "iconSize" })[key], value)
    }

    LayerShell.Window.scope: "enclave-taskbar"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
                               | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: autoHide ? 0 : Theme.taskbarHeight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Pinned apps first (taskbar pins), then any other running app. Each
    // group holds that app's open windows; Apps.matchAppId prefers a pinned
    // id, so a pinned app's windows land on its pinned icon.
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
        peek.close()
        if (g.windows.length === 0) {
            Apps.launch(g.appId)
            return true
        }
        if (g.windows.length === 1) {
            Windows.toggleMinimize(g.windows[0].index)
            return false
        }
        cycleGroup(g, 1)
        return false
    }
    // Bring the next (step 1) or previous (step -1) window of an app forward.
    function cycleGroup(g, step) {
        const n = g.windows.length
        if (n === 0) return
        let cur = -1
        for (let i = 0; i < n; ++i)
            if (g.windows[i].activated && !g.windows[i].minimized) cur = i
        const next = cur < 0 ? 0 : (cur + step + n) % n
        Windows.activate(g.windows[next].index)
    }

    // ---- drag to reorder pins ----
    property int dragFrom: -1
    property int dragTo: -1
    function dragTarget(from, dx, step) {
        return Math.max(0, Math.min(pinnedGroups.length - 1, from + Math.round(dx / step)))
    }
    function shiftFor(i, step) {
        if (dragFrom < 0 || i === dragFrom) return 0
        if (dragFrom < dragTo && i > dragFrom && i <= dragTo) return -step
        if (dragTo < dragFrom && i >= dragTo && i < dragFrom) return step
        return 0
    }
    function finishDrag(appId) {
        if (dragTo >= 0 && dragTo !== dragFrom) {
            const target = pinnedGroups[dragTo].appId
            Apps.moveTaskbarPin(appId, Apps.taskbarPins.indexOf(target))
        }
        dragFrom = -1
        dragTo = -1
    }

    // ---- the window list (hover an open app) ----
    property Item peekCandidate: null
    function hoverChanged(item, pointed) {
        if (pointed && item.group && item.group.windows.length > 0) {
            if (peek.visible && peek.anchorItem !== item) { peek.anchorItem = item; peek.group = item.group }
            peekCandidate = item
            if (!peek.visible) peekTimer.restart()
            peekClose.stop()
        } else if (peekCandidate === item) {
            peekCandidate = null
            peekTimer.stop()
            peekClose.restart()
        }
    }
    function openPeek(item) {
        if (!item || !item.group || item.group.windows.length === 0) return
        peek.anchorItem = item
        peek.group = item.group
        peek.open()
    }
    Timer { id: peekTimer; interval: 550; onTriggered: root.openPeek(root.peekCandidate) }
    Timer {
        id: peekClose
        interval: 300
        onTriggered: if (!peek.hovered && !root.peekCandidate) peek.close()
    }
    WindowPeek {
        id: peek
        anchorItem: dock
        onActivated: (index) => Windows.activate(index)
        onCloseRequested: (index) => Windows.close(index)
        onHoveredChanged: if (!hovered) peekClose.restart()
    }
    // keep an open list in step with its app's windows
    onGroupsChanged: {
        if (!peek.visible || !peek.group) return
        const g = groups.find(x => x.appId === peek.group.appId)
        if (!g || g.windows.length === 0) peek.close()
        else peek.group = g
    }

    // ---- the Trash ----
    property bool trashFull: false
    function refreshTrash() {
        System.query("sh", ["-c", "ls -A \"${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files\" 2>/dev/null | head -n 1"],
                     (out) => root.trashFull = out.length > 0)
    }
    Timer { interval: 4000; repeat: true; running: root.showTrash; triggeredOnStart: true; onTriggered: root.refreshTrash() }

    // ---- auto-hide ----
    readonly property bool menuOpen: dockMenu.visible || trashMenu.visible || peek.visible
    property bool revealed: !autoHide
    onAutoHideChanged: revealed = !autoHide
    Timer {
        id: hideTimer
        interval: 900
        onTriggered: if (root.autoHide && !dockHover.hovered && !root.menuOpen && !root.startOpen) root.revealed = false
    }
    onStartOpenChanged: if (!startOpen && autoHide) hideTimer.restart()
    onMenuOpenChanged: if (!menuOpen && autoHide) hideTimer.restart()

    // only the island (or, hidden, a thin edge strip) takes input
    function updateInputRegion() {
        if (!visible) return
        if (revealed)
            System.setInputRegion(root, Qt.rect(Math.round(dock.x), root.gap, Math.round(dock.width), root.islandHeight + root.gap))
        else
            System.setInputRegion(root, Qt.rect(Math.round(dock.x), root.height - 4, Math.round(dock.width), 4))
    }
    onRevealedChanged: updateInputRegion()
    onWidthChanged: updateInputRegion()
    Component.onCompleted: { reloadOptions(); updateInputRegion() }

    // A taskbar app (pinned or running); shared by both dock repeaters.
    Component {
        id: taskDelegate
        DockItem {
            id: task
            required property var modelData
            required property int index
            readonly property var group: modelData
            readonly property int step: width
            height: root.islandHeight
            iconSize: root.iconSize
            magnify: root.magnify
            pointerX: dockHover.hovered ? dockHover.point.position.x : -1
            offsetX: dockRow.x
            icon: modelData.icon
            name: modelData.name
            windowCount: modelData.windows.length
            active: modelData.windows.some(w => w.activated && !w.minimized)
            checked: taskMenu.visible
            showLabel: !(peek.visible && peek.anchorItem === task)
            draggable: modelData.pinned
            shiftX: modelData.pinned ? root.shiftFor(index, step) : 0
            onPointedChanged: root.hoverChanged(task, pointed)
            onClicked: if (root.clickGroup(modelData)) launching = true
            onMiddleClicked: if (!modelData.appId.startsWith("window:")) { Apps.launch(modelData.appId); if (!running) launching = true }
            onScrolled: (steps) => root.cycleGroup(modelData, steps)
            onRightClicked: { peek.close(); taskMenu.popup(task, 0, -taskMenu.implicitHeight - 8) }
            onDragMoved: (dx) => { peek.close(); root.dragFrom = index; root.dragTo = root.dragTarget(index, dx, step) }
            onDropped: root.finishDrag(modelData.appId)

            EmberMenu {
                id: taskMenu
                // the app's windows first, so any one can be raised from here too
                Instantiator {
                    model: task.modelData.windows
                    delegate: MenuItem {
                        required property var modelData
                        text: (modelData.activated && !modelData.minimized ? "●  " : "    ")
                              + (modelData.title || task.modelData.name)
                        onTriggered: Windows.activate(modelData.index)
                    }
                    onObjectAdded: (i, o) => taskMenu.insertItem(i, o)
                    onObjectRemoved: (i, o) => taskMenu.removeItem(o)
                }
                MenuSeparator { visible: task.running; height: visible ? implicitHeight : 0 }
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
                    text: task.modelData.windows.length > 1 ? "Close all " + task.modelData.windows.length + " windows" : "Close window"
                    visible: task.running
                    height: visible ? implicitHeight : 0
                    onTriggered: task.modelData.windows.slice().reverse().forEach(w => Windows.close(w.index))
                }
            }
        }
    }

    component Divider: Item {
        width: 17
        height: root.islandHeight
        Rectangle {
            anchors.centerIn: parent
            width: 1; height: Math.round(root.islandHeight * 0.55)
            color: Theme.c.border
        }
    }

    // ---------------- the dock ----------------
    Item {
        id: dock
        height: root.islandHeight
        width: dockRow.width + 12
        y: root.revealed ? root.gap : root.height - 3
        x: Math.round((root.width - width) / 2)
        onXChanged: root.updateInputRegion()
        onWidthChanged: root.updateInputRegion()
        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }

        Glass { anchors.fill: parent; radius: root.islandRadius }
        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) { hideTimer.stop(); root.revealed = true }
                else if (root.autoHide) hideTimer.restart()
            }
        }
        // right-click on the island itself (not an icon): the dock's options
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (pt) => dockMenu.popup(dock, pt.position.x - 110, -dockMenu.implicitHeight - 8)
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 0

            DockItem {
                height: root.islandHeight
                magnify: root.magnify
                pointerX: dockHover.hovered ? dockHover.point.position.x : -1
                offsetX: dockRow.x
                icon: "/usr/share/enclave/" + (Theme.dark ? "enclave-logo-dark.svg" : "enclave-logo.svg")
                name: "Start"
                iconSize: root.iconSize - 6
                checked: root.startOpen && root.startPage !== "all"
                onClicked: { peek.close(); root.startRequested() }
            }

            Repeater {
                model: root.pinnedGroups
                delegate: taskDelegate
            }

            Divider { visible: root.otherGroups.length > 0 }

            Repeater {
                model: root.otherGroups
                delegate: taskDelegate
            }

            Divider {}

            DockItem {
                height: root.islandHeight
                magnify: root.magnify
                pointerX: dockHover.hovered ? dockHover.point.position.x : -1
                offsetX: dockRow.x
                icon: "view-app-grid-symbolic?color=" + encodeURIComponent(Theme.c.text)
                iconSize: Math.round(root.iconSize * 0.65)
                name: "All apps"
                checked: root.startOpen && root.startPage === "all"
                onClicked: { peek.close(); root.allAppsRequested() }
            }

            DockItem {
                id: trash
                visible: root.showTrash
                height: root.islandHeight
                magnify: root.magnify
                iconSize: root.iconSize
                pointerX: dockHover.hovered ? dockHover.point.position.x : -1
                offsetX: dockRow.x
                icon: root.trashFull ? "user-trash-full" : "user-trash"
                name: root.trashFull ? "Trash" : "Trash · empty"
                checked: trashMenu.visible
                onClicked: { root.interacted(); System.run("enclave-files", ["trash:///"]) }
                onRightClicked: trashMenu.popup(trash, 0, -trashMenu.implicitHeight - 8)

                EmberMenu {
                    id: trashMenu
                    MenuItem { text: "Open Trash"; onTriggered: System.run("enclave-files", ["trash:///"]) }
                    MenuItem {
                        text: "Empty Trash"
                        enabled: root.trashFull
                        onTriggered: System.query("gio", ["trash", "--empty"], () => root.refreshTrash())
                    }
                }
            }
        }
    }

    EmberMenu {
        id: dockMenu
        MenuItem {
            text: "Magnify icons"
            checkable: true
            checked: root.magnify
            onTriggered: root.setOption("magnify", checked)
        }
        MenuItem {
            text: "Hide the dock automatically"
            checkable: true
            checked: root.autoHide
            onTriggered: root.setOption("autoHide", checked)
        }
        MenuItem {
            text: "Show Trash"
            checkable: true
            checked: root.showTrash
            onTriggered: root.setOption("showTrash", checked)
        }
        MenuSeparator {}
        MenuItem { text: "Small icons"; checkable: true; checked: root.iconSize === 34; onTriggered: root.setOption("iconSize", 34) }
        MenuItem { text: "Medium icons"; checkable: true; checked: root.iconSize === 40; onTriggered: root.setOption("iconSize", 40) }
        MenuItem { text: "Large icons"; checkable: true; checked: root.iconSize === 46; onTriggered: root.setOption("iconSize", 46) }
        MenuSeparator {}
        MenuItem { text: "Dock settings…"; onTriggered: System.run("enclave-settings", ["--page", "desktop"]) }
    }

    // for scripted tests and keyboard users: open the window list of the first open app
    function peekFirst() {
        for (let i = 0; i < dockRow.children.length; ++i) {
            const c = dockRow.children[i]
            if (c.group && c.group.windows && c.group.windows.length > 0) { openPeek(c); return }
        }
    }
    function showMenu() { dockMenu.popup(dock, dock.width / 2 - 110, -dockMenu.implicitHeight - 8) }
}
