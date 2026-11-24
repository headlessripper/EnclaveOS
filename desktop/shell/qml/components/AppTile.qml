// Start-menu tile: app icon over its name (pinned grid).
import QtQuick
import Enclave

Item {
    id: root
    property string icon: ""
    property string label: ""
    property bool highlighted: false
    signal clicked()
    signal rightClicked()

    implicitWidth: 96
    implicitHeight: 82

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radius.small
        color: mouse.pressed ? Theme.c.pressed
             : (mouse.containsMouse || root.highlighted) ? Theme.c.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32; height: 32
            sourceSize: Qt.size(64, 64)
            source: root.icon === "" ? "" : "image://icon/" + root.icon
        }
        Text {
            width: root.width - 12
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: Theme.c.text
            font.pointSize: 9
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
