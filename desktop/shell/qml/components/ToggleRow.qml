// Control Center toggle: a round switch (orange when on) and a label.
// Clicking the circle toggles; clicking the label opens more ("opened").
import QtQuick
import Enclave

Item {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool on: false
    signal toggled()
    signal opened()

    implicitWidth: 150
    implicitHeight: 40

    Rectangle {
        id: knob
        width: 30; height: 30; radius: 15
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: root.on ? Theme.c.accent : (knobMouse.pressed ? Theme.c.pressed : Theme.c.hover)
        border.width: 1
        border.color: root.on || knobMouse.containsMouse ? Theme.c.accent : Theme.c.border
        scale: knobMouse.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: root.icon === "" ? "" : "image://icon/" + root.icon + "?color="
                    + encodeURIComponent(root.on ? Theme.c.accentText : Theme.c.text)
        }
        MouseArea { id: knobMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggled() }
    }

    Rectangle {
        anchors { left: knob.right; leftMargin: 4; right: parent.right; verticalCenter: parent.verticalCenter }
        height: parent.height
        radius: Theme.radius.small
        color: labelMouse.containsMouse ? Theme.c.hover : "transparent"
        Column {
            anchors { left: parent.left; leftMargin: 6; right: parent.right; rightMargin: 4
                      verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width
                text: root.title
                color: Theme.c.text
                font.pointSize: 9.5
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: Theme.c.textSecondary
                font.pointSize: 8.5
                elide: Text.ElideRight
            }
        }
        MouseArea { id: labelMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.opened() }
    }
}
