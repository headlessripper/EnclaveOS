// Ember search field: pill shape, orange focus underline (Windows 11 + macOS).
import QtQuick
import QtQuick.Controls
import Enclave

TextField {
    id: root
    implicitHeight: 40
    leftPadding: 40
    rightPadding: 16
    color: Theme.c.text
    placeholderTextColor: Theme.c.textSecondary
    selectionColor: Theme.brand.glow
    selectedTextColor: "#202124"
    font.pointSize: 10

    background: Rectangle {
        radius: height / 2
        color: Theme.dark ? Theme.c.elevated : Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        clip: true
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            width: root.activeFocus ? parent.width - parent.radius : 0
            color: Theme.c.accent
            Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        }
        Image {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: "image://icon/system-search-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
        }
    }
}
