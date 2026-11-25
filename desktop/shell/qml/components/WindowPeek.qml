// The dock's window list: hovering an icon whose app has windows open floats a
// card above it naming each window (the one in front marked in ember), with a
// close button per row. Click a row to bring that window forward. It lives in
// its own popup so it can rise above the dock surface; it stays open while
// either the icon or the card is under the pointer.
import QtQuick
import QtQuick.Controls
import Enclave

ToolTip {
    id: peek
    popupType: Popup.Window
    delay: 0
    timeout: -1
    property var group: null                 // { name, icon, windows: [...] }
    property Item anchorItem: null
    readonly property bool hovered: cardHover.hovered
    signal activated(int index)
    signal closeRequested(int index)

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 8
    width: 280
    parent: anchorItem
    x: anchorItem ? anchorItem.width / 2 - width / 2 : 0
    y: -implicitHeight - 10

    background: Rectangle {
        radius: Theme.radius.medium + 2
        color: Theme.dark ? Theme.c.elevated : Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.fast }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.motion.fast; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.motion.fast } }

    contentItem: Column {
        spacing: 2
        HoverHandler { id: cardHover }

        // header: the app
        Row {
            spacing: 8
            leftPadding: 6
            bottomPadding: 4
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                sourceSize: Qt.size(36, 36)
                source: peek.group && peek.group.icon ? "image://icon/" + peek.group.icon : ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: peek.group ? peek.group.name : ""
                color: Theme.c.textSecondary
                font.pointSize: 8.5
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!peek.group && peek.group.windows.length > 1
                text: peek.group ? peek.group.windows.length + " windows" : ""
                color: Theme.c.textSecondary
                font.pointSize: 8
                opacity: 0.7
            }
        }

        Repeater {
            model: peek.group ? peek.group.windows : []
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool front: modelData.activated && !modelData.minimized
                width: peek.availableWidth
                height: 36
                radius: Theme.radius.small + 2
                color: rowMouse.containsMouse ? Theme.c.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    width: 3; height: 16; radius: 1.5
                    color: row.front ? Theme.c.accent : "transparent"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    width: parent.width - 14 - 34
                    text: row.modelData.title || peek.group.name
                    color: Theme.c.text
                    opacity: row.modelData.minimized ? 0.55 : 1
                    font.pointSize: 9.5
                    font.weight: row.front ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { peek.activated(row.modelData.index); peek.close() }
                }
                // close
                Rectangle {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 22; height: 22; radius: 11
                    visible: rowMouse.containsMouse || closeMouse.containsMouse
                    color: closeMouse.containsMouse ? Theme.status.danger : Theme.c.pressed
                    Image {
                        anchors.centerIn: parent
                        width: 10; height: 10
                        sourceSize: Qt.size(20, 20)
                        source: "image://icon/window-close-symbolic?color="
                                + encodeURIComponent(closeMouse.containsMouse ? Theme.c.accentText : Theme.c.text)
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: peek.closeRequested(row.modelData.index)
                    }
                }
            }
        }
    }
}
