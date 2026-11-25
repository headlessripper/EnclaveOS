// Enclave Shell — the desktop search widget: a floating glass pill at the top
// centre of the desktop. It opens Search (the same as Super+Space). Lives on
// the desktop layer, under windows, like the other widgets.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: System.setting("desktop/search", true) !== "false"
    color: "transparent"
    title: "Enclave Search Widget"
    width: 580
    height: 78
    signal searchRequested()

    LayerShell.Window.scope: "enclave-search-widget"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    Item {
        id: pill
        x: 12; y: 16
        width: root.width - 24
        height: 50
        scale: mouse.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }

        Glass { anchors.fill: parent; radius: height / 2; shadowDepth: 3 }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: mouse.containsMouse ? Theme.c.hover : "transparent"
            border.width: 1
            border.color: mouse.containsMouse ? Qt.alpha(Theme.c.accent, 0.7) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }
        }

        // an ember "spark" disc carrying the search glyph
        Rectangle {
            id: disc
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.brand.solar }
                GradientStop { position: 1; color: Theme.brand.burnt }
            }
            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                sourceSize: Qt.size(32, 32)
                source: "image://icon/system-search-symbolic?color=%23FFFFFF"
            }
        }
        Column {
            anchors { left: disc.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 1
            Text {
                text: "Search anything"
                color: Theme.c.text
                font.pointSize: 10.5
                font.weight: Font.DemiBold
            }
            Text {
                text: "Apps, settings, files, sums and the web"
                color: Theme.c.textSecondary
                font.pointSize: 8.5
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
                model: ["Super", "Space"]
                delegate: Rectangle {
                    required property string modelData
                    width: keyText.implicitWidth + 14
                    height: 22
                    radius: Theme.radius.small
                    color: Theme.c.hover
                    border.width: 1
                    border.color: Theme.c.border
                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.c.textSecondary
                        font.pointSize: 8
                        font.weight: Font.Medium
                    }
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.searchRequested()
        }
    }
}
