// One dock icon: gentle magnification toward the pointer, a press dip, a
// bounce while its app is launching, and the running indicator under the
// icon — one dot per open window (up to three), an ember bar when one of them
// is in front. Pinned icons can be dragged sideways to reorder the dock.
import QtQuick
import Enclave

Item {
    id: item
    property string icon: ""
    property string name: ""
    property int windowCount: 0
    readonly property bool running: windowCount > 0
    property bool active: false
    property bool checked: false
    property bool launching: false
    property bool showLabel: true
    property bool draggable: false
    property bool magnify: true
    property real shiftX: 0             // nudged aside while a neighbour is dragged past
    Behavior on shiftX { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
    property int iconSize: 40
    property real pointerX: -1          // pointer x in the same coordinates as centreX; -1 = away
    property real offsetX: 0            // this item's parent x within those coordinates
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int steps)
    signal dragMoved(real dx)           // while dragging, how far from home
    signal dropped(real dx)

    width: iconSize + 16
    height: 64

    readonly property real centreX: offsetX + x + width / 2
    readonly property bool pointed: pointerX >= 0 && Math.abs(pointerX - centreX) < width / 2
    readonly property real mag: !magnify || Theme.reducedMotion || pointerX < 0 || dragging ? 0
        : Math.max(0, 1 - Math.abs(pointerX - centreX) / 110)
    readonly property bool hovered: mouse.containsMouse
    property real bounce: 0
    property bool dragging: false
    property real dragX: 0
    z: dragging ? 10 : 0

    onRunningChanged: if (running) launching = false
    Timer { interval: 6000; running: item.launching; onTriggered: item.launching = false }
    SequentialAnimation {
        running: item.launching && !Theme.reducedMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) item.bounce = 0
        NumberAnimation { target: item; property: "bounce"; to: -12; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: item; property: "bounce"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 80 }
    }

    // pressed / open wash (Start open, menu open)
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: item.iconSize + 10; height: width
        radius: Theme.radius.medium + 2
        color: mouse.pressed && !item.dragging ? Theme.c.pressed : item.checked ? Theme.c.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    }

    Image {
        id: glyph
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: item.dragX + item.shiftX
        y: (parent.height - height) / 2 - 2 - item.mag * 4 + item.bounce - (item.dragging ? 6 : 0)
        width: item.iconSize; height: item.iconSize
        sourceSize: Qt.size(item.iconSize * 2, item.iconSize * 2)
        source: item.icon === "" ? "" : "image://icon/" + item.icon
        scale: (1 + item.mag * 0.18) * (mouse.pressed && !item.dragging ? 0.9 : 1) * (item.dragging ? 1.08 : 1)
        opacity: item.dragging ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !item.launching; NumberAnimation { duration: 90 } }
    }

    // the running indicator: dots for windows, an ember bar for the one in front
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        spacing: 3
        visible: !item.active
        opacity: item.running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }
        Repeater {
            model: Math.min(3, Math.max(1, item.windowCount))
            delegate: Rectangle { width: 4; height: 4; radius: 2; color: Theme.c.textSecondary }
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        height: 4; radius: 2
        width: item.active ? (item.windowCount > 1 ? 22 : 14) : 4
        opacity: item.active ? 1 : 0
        color: Theme.c.accent
        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        property real pressX: 0
        onPressed: (e) => pressX = e.x
        onPositionChanged: (e) => {
            if (!item.draggable || !(e.buttons & Qt.LeftButton)) return
            const dx = e.x - pressX
            if (!item.dragging && Math.abs(dx) > 10) item.dragging = true
            if (item.dragging) { item.dragX = dx; item.dragMoved(dx) }
        }
        onReleased: (e) => {
            if (item.dragging) {
                const dx = item.dragX
                item.dragging = false
                item.dragX = 0
                item.dropped(dx)
            }
        }
        onClicked: (e) => {
            if (e.button === Qt.RightButton) item.rightClicked()
            else if (e.button === Qt.MiddleButton) item.middleClicked()
            else item.clicked()
        }
        onWheel: (w) => item.scrolled(w.angleDelta.y > 0 ? -1 : 1)
    }

    HoverLabel {
        text: item.name
        visible: item.showLabel && item.pointed && !mouse.pressed && !item.checked && !item.dragging && item.name !== ""
    }
}
