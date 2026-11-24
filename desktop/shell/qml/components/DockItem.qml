// One dock icon: gentle magnification toward the pointer, a press dip, a
// bounce while its app is launching, the running dot (an orange bar for the
// window in front) and a floating name label.
import QtQuick
import Enclave

Item {
    id: item
    property string icon: ""
    property string name: ""
    property bool running: false
    property bool active: false
    property bool checked: false
    property bool launching: false
    property int iconSize: 40
    property real pointerX: -1          // pointer x in the same coordinates as centreX; -1 = away
    property real offsetX: 0            // this item's parent x within those coordinates
    signal clicked()
    signal rightClicked()

    width: 56
    height: 64

    readonly property real centreX: offsetX + x + width / 2
    readonly property bool pointed: pointerX >= 0 && Math.abs(pointerX - centreX) < width / 2
    readonly property real mag: Theme.reducedMotion || pointerX < 0 ? 0
        : Math.max(0, 1 - Math.abs(pointerX - centreX) / 110)
    property real bounce: 0

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
        width: 50; height: 50
        radius: Theme.radius.medium + 2
        color: mouse.pressed ? Theme.c.pressed : item.checked ? Theme.c.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    }

    Image {
        id: glyph
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - 2 - item.mag * 4 + item.bounce
        width: item.iconSize; height: item.iconSize
        sourceSize: Qt.size(item.iconSize * 2, item.iconSize * 2)
        source: item.icon === "" ? "" : "image://icon/" + item.icon
        scale: (1 + item.mag * 0.18) * (mouse.pressed ? 0.9 : 1)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        height: 4; radius: 2
        width: item.active ? 14 : (item.running ? 4 : 0)
        opacity: item.running ? 1 : 0
        color: item.active ? Theme.c.accent : Theme.c.textSecondary
        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => e.button === Qt.RightButton ? item.rightClicked() : item.clicked()
    }

    HoverLabel {
        text: item.name
        visible: item.pointed && !mouse.pressed && !item.checked && item.name !== ""
    }
}
