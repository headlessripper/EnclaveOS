// macOS-style name label floating above a dock icon (its own popup, so it can
// sit outside the taskbar surface).
import QtQuick
import QtQuick.Controls
import Enclave

ToolTip {
    id: tip
    popupType: Popup.Window
    delay: 250
    padding: 0
    y: -implicitHeight - 10
    x: (parent ? parent.width : 0) / 2 - implicitWidth / 2
    contentItem: Text {
        leftPadding: 12; rightPadding: 12; topPadding: 5; bottomPadding: 6
        text: tip.text
        color: Theme.c.text
        font.pointSize: 9
    }
    background: Rectangle {
        radius: Theme.radius.small + 2
        color: Theme.dark ? Theme.c.elevated : Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.fast } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.motion.fast } }
}
