// Enclave Shell — the signature floating bubble.
//
// One small round bubble floats over everything. Drag it anywhere and it
// settles on the nearest side edge (and remembers the spot). Click it and its
// controls fan out on an arc that faces the middle of the screen, so they never
// fall off an edge or a corner: minimise, maximise/restore and close for the
// window in front (Enclave windows have no title bar, so this is where they
// are controlled), snap left/right and move, plus screenshot and quick settings. A press
// anywhere else folds them back in. The badge shows which app it controls.
//
// Wayland: the bubble is a full-screen, transparent layer-shell surface whose
// input region is just the bubble (everything around it stays click-through);
// while open or dragging it takes the whole screen, so an outside press folds
// it and the drag can follow the pointer anywhere. Window actions go through
// the WindowManager interface (wlr-foreign-toplevel).
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave

Window {
    id: root
    visible: !Windows.activeFullscreen
    color: "transparent"
    title: "Enclave Bubble"

    signal controlCenterRequested()
    signal screenshotRequested()

    readonly property int size: 44
    readonly property int edge: 12
    readonly property int radius: 64
    readonly property int dragSlop: 4
    readonly property int bottomGap: Theme.taskbarHeight + edge

    // where it rests: a side and a height (persisted)
    property string side: System.setting("bubble/side", "right")
    property real restTop: Number(System.setting("bubble/top", -1))
    property bool open: false
    property bool dragging: false
    property point dragPos: Qt.point(0, 0)

    readonly property bool hasTarget: Windows.activeIndex >= 0
    readonly property string targetIcon: {
        const id = Apps.matchAppId(Windows.activeAppId)
        return id ? Apps.app(id).icon : (Windows.activeAppId || "")
    }

    LayerShell.Window.scope: "enclave-bubble"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    // Never take keyboard focus: the window in front must stay the target.
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    readonly property int topGap: Theme.topBarHeight + edge
    function clampTop(t) { return Math.min(Math.max(t, topGap), height - size - bottomGap) }

    readonly property real restLeft: side === "left" ? edge : width - size - edge
    readonly property real bx: dragging ? Math.min(Math.max(dragPos.x - size / 2, edge), width - size - edge) : restLeft
    readonly property real by: dragging ? clampTop(dragPos.y - size / 2)
                                        : clampTop(restTop < 0 ? height - bottomGap - size - 24 : restTop)

    // The fan: an arc facing the middle of the screen; a quarter turn on a
    // wider ring when tucked into a corner.
    readonly property real cx: bx + size / 2
    readonly property real cy: by + size / 2
    readonly property real facing: Math.atan2(height / 2 - cy, width / 2 - cx)
    readonly property bool cornered: cy < topGap + radius + size || cy > height - radius - size - bottomGap
    readonly property real arc: cornered ? Math.PI / 2 : Math.PI * 0.85
    // wide enough that the buttons never touch (38px each plus a gap)
    readonly property real ring: Math.max(cornered ? radius + 66 : radius + 24,
                                          (controls.length - 1) * 46 / arc)

    // Windows carry no title bar in Enclave: these are their controls. Snap
    // and Move press labwc's own window shortcuts (rc.xml) through wtype, so
    // they act on the window in front.
    function key(mods, k) {
        const args = []
        for (const m of mods) args.push("-M", m)
        args.push("-k", k)
        for (const m of mods.slice().reverse()) args.push("-m", m)
        System.run("wtype", args)
    }
    readonly property var controls: [
        { label: "Minimise", icon: "window-minimize-symbolic", target: true,
          run: () => Windows.activeMinimize() },
        { label: Windows.activeMaximized ? "Restore" : "Maximise",
          icon: Windows.activeMaximized ? "window-restore-symbolic" : "window-maximize-symbolic", target: true,
          run: () => Windows.activeToggleMaximize() },
        { label: "Snap left", icon: "go-first-symbolic", target: true, run: () => root.key(["logo"], "Left") },
        { label: "Snap right", icon: "go-last-symbolic", target: true, run: () => root.key(["logo"], "Right") },
        { label: "Move (click to drop)", icon: "view-fullscreen-symbolic", target: true, run: () => root.key(["alt"], "F7") },
        { label: "Screenshot", icon: "camera-photo-symbolic", run: () => root.screenshotRequested() },
        { label: "Quick settings", icon: "emblem-system-symbolic", run: () => root.controlCenterRequested() },
        { label: "Close", icon: "window-close-symbolic", target: true, danger: true,
          run: () => Windows.activeClose() },
    ]

    // Input: just the bubble while resting; the whole screen while open or
    // dragging (so an outside press folds it, and the drag can go anywhere).
    function updateInput() {
        if (open || dragging)
            System.setInputRegion(root, Qt.rect(0, 0, 0, 0))
        else
            System.setInputRegion(root, Qt.rect(Math.round(bx) - 4, Math.round(by) - 4, size + 8, size + 8))
    }
    onOpenChanged: updateInput()
    onDraggingChanged: updateInput()
    onBxChanged: if (!dragging) updateInput()
    onByChanged: if (!dragging) updateInput()
    onWidthChanged: updateInput()
    onHeightChanged: updateInput()
    onVisibleChanged: if (!visible) open = false
    Component.onCompleted: updateInput()

    // Outside press (only reachable while open): fold the controls in.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onPressed: root.open = false
    }

    // ---- the controls, fanned out on the arc ----
    Repeater {
        model: root.controls
        delegate: Item {
            id: ctl
            required property var modelData
            required property int index
            readonly property real angle: root.facing - root.arc / 2
                                          + index * (root.arc / (root.controls.length - 1))
            readonly property bool usable: !modelData.target || root.hasTarget
            width: 38; height: 38
            x: root.cx - width / 2 + (root.open ? Math.cos(angle) * root.ring : 0)
            y: root.cy - height / 2 + (root.open ? Math.sin(angle) * root.ring : 0)
            scale: root.open ? 1 : 0.4
            opacity: root.open ? (usable ? 1 : 0.4) : 0
            visible: opacity > 0.01
            Behavior on x { SequentialAnimation { PauseAnimation { duration: root.open ? ctl.index * 25 : 0 }
                NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } } }
            Behavior on y { SequentialAnimation { PauseAnimation { duration: root.open ? ctl.index * 25 : 0 }
                NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } } }
            Behavior on scale { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ctlMouse.containsMouse && ctl.usable
                       ? (ctl.modelData.danger ? Theme.status.danger : Theme.c.surface)
                       : Theme.c.glass
                border.width: 1
                border.color: ctlMouse.containsMouse && ctl.usable
                              ? (ctl.modelData.danger ? Theme.status.danger : Theme.c.accent)
                              : Theme.c.border
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            }
            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                sourceSize: Qt.size(32, 32)
                source: "image://icon/" + ctl.modelData.icon + "?color=" + encodeURIComponent(
                            ctlMouse.containsMouse && ctl.usable
                            ? (ctl.modelData.danger ? "white" : Theme.c.accent) : Theme.c.text)
            }
            MouseArea {
                id: ctlMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.open
                onClicked: {
                    if (!ctl.usable) return
                    root.open = false
                    ctl.modelData.run()
                }
            }
            ToolTip.visible: ctlMouse.containsMouse && root.open
            ToolTip.delay: 350
            ToolTip.text: ctl.modelData.label + (ctl.modelData.target && root.hasTarget && Windows.activeTitle
                                                 ? " — " + Windows.activeTitle : "")
        }
    }

    // ---- the bubble ----
    Item {
        id: bubble
        x: root.bx
        y: root.by
        width: root.size
        height: root.size
        scale: root.dragging ? 1.1 : 1
        Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
        Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }

        // soft shadow
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2
                width: root.size + (index + 1) * 4
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.16 : 0.07) / (index + 1))
            }
        }

        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            color: Theme.c.glass
            border.width: root.open ? 2 : 1
            border.color: root.open ? Theme.c.accent : Theme.c.border
            opacity: root.open || root.dragging || press.containsMouse ? 1 : 0.78
            Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }
            Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }

            Image {
                anchors.centerIn: parent
                width: 22; height: 22
                sourceSize: Qt.size(44, 44)
                source: "file:///usr/share/enclave/" + (Theme.dark ? "enclave-logo-dark.svg" : "enclave-logo.svg")
                rotation: root.open ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutCubic } }
            }
        }

        // which app the bubble is controlling
        Rectangle {
            visible: root.hasTarget && root.targetIcon !== "" && !root.open
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -3
            width: 18; height: 18; radius: 9
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border
            Image {
                anchors.centerIn: parent
                width: 12; height: 12
                sourceSize: Qt.size(24, 24)
                source: parent.visible ? "image://icon/" + root.targetIcon : ""
            }
        }

        MouseArea {
            id: press
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point start
            property bool moved: false
            onPressed: (e) => { start = mapToItem(null, e.x, e.y); moved = false }
            onPositionChanged: (e) => {
                if (!pressed) return
                const p = mapToItem(null, e.x, e.y)
                if (!moved && Math.hypot(p.x - start.x, p.y - start.y) < root.dragSlop) return
                if (!moved) { moved = true; root.open = false; root.dragging = true }
                root.dragPos = p
            }
            onReleased: (e) => {
                if (!moved) { root.open = !root.open; return }
                const p = mapToItem(null, e.x, e.y)
                root.side = p.x < root.width / 2 ? "left" : "right"
                root.restTop = root.clampTop(p.y - root.size / 2)
                root.dragging = false
                System.setSetting("bubble/side", root.side)
                System.setSetting("bubble/top", Math.round(root.restTop))
            }
        }

        ToolTip.visible: press.containsMouse && !root.open && !root.dragging
        ToolTip.delay: 900
        ToolTip.text: root.hasTarget ? "Controls for " + (Windows.activeTitle || "this window") : "Enclave bubble"
    }
}
