// Ember icon button: rounded hover/press wash, optional symbolic tint.
import QtQuick
import QtQuick.Controls
import Enclave

Item {
    id: root
    property string icon: ""          // freedesktop icon name or absolute path
    property bool symbolic: false     // recolour to the Ember text colour
    property color tint: Theme.c.text
    property int iconSize: 20
    property string tooltip: ""
    property bool checked: false
    property real radius: Theme.radius.small
    signal clicked()
    signal rightClicked()

    implicitWidth: 40
    implicitHeight: 40
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: mouse.pressed ? Theme.c.pressed
             : (mouse.containsMouse || root.checked) ? Theme.c.hover : "transparent"
        border.width: root.checked ? 1 : 0
        border.color: Theme.c.border
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    }

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        source: root.icon === "" ? ""
              : "image://icon/" + root.icon + (root.symbolic ? "?color=" + encodeURIComponent(root.tint) : "")
        scale: mouse.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    ToolTip.visible: tooltip !== "" && mouse.containsMouse
    ToolTip.delay: 600
    ToolTip.text: tooltip
}
