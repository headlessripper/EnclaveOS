// Control Center slider: a thick pill track, Ember fill, white knob, and the
// icon inside the track.
import QtQuick
import QtQuick.Controls
import Enclave

Slider {
    id: s
    property string icon: ""
    from: 0
    to: 1
    padding: 0
    implicitWidth: 200
    implicitHeight: 26

    background: Rectangle {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: 24
        radius: 12
        color: Theme.c.pressed
        Rectangle {
            height: parent.height
            radius: 12
            width: Math.max(height, s.handle.x - s.leftPadding + s.handle.width)
            color: Theme.c.accent
        }
        Image {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: s.icon === "" ? "" : "image://icon/" + s.icon + "?color=" + encodeURIComponent(Theme.c.accentText)
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 24; height: 24; radius: 12
        color: "white"
        border.width: 1
        border.color: Theme.c.border
        scale: s.pressed ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }
    }
}
