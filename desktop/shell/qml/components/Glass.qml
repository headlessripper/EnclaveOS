// Ember glass: the one surface every floating piece of the shell is made of
// (dock, status island, Start, Control Center, calendar). Soft layered
// shadow, near-opaque glass, a hairline border and a faint top highlight.
import QtQuick
import Enclave

Item {
    id: root
    property real radius: Theme.radius.large
    property color fill: Theme.c.glass
    property int shadowDepth: 4

    Repeater {
        model: root.shadowDepth
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: -(index + 1) * 2
            anchors.topMargin: -(index + 1) * 2 + 3
            radius: root.radius + (index + 1) * 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.16 : 0.06) / (index + 1))
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.width: 1
        border.color: Theme.c.border
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: root.radius; rightMargin: root.radius; topMargin: 1 }
        height: 1
        color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.8)
    }
}
