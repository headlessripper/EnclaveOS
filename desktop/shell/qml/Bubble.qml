// Enclave Shell — the signature floating control bubble, on Wayland.
// Controls the window in front through the WindowManager interface
// (wlr-foreign-toplevel), so it respects Wayland's security model.
// Dims when there is no window to control, hides for fullscreen apps.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: !Windows.activeFullscreen
    color: "transparent"
    title: "Enclave Bubble"
    width: pill.width + 16
    height: 52

    readonly property bool hasTarget: Windows.activeIndex >= 0
    readonly property string targetIcon: {
        const id = Apps.matchAppId(Windows.activeAppId)
        return id ? Apps.app(id).icon : (Windows.activeAppId || "")
    }

    // Anchored to the top edge only: the compositor centres it.
    LayerShell.Window.scope: "enclave-bubble"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: row.implicitWidth + 12
        height: 36
        radius: height / 2
        color: Theme.c.glass
        border.width: 1
        border.color: Theme.c.border
        opacity: root.hasTarget ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 2

            // which window the bubble is controlling
            Item {
                width: 30; height: 30
                Image {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    sourceSize: Qt.size(36, 36)
                    visible: root.hasTarget && root.targetIcon !== ""
                    source: visible ? "image://icon/" + root.targetIcon : ""
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.hasTarget
                    width: 8; height: 8; radius: 4
                    color: Theme.brand.ember
                }
            }
            IconButton {
                width: 30; height: 30; radius: 15; iconSize: 14
                icon: "window-minimize-symbolic"; symbolic: true
                enabled: root.hasTarget
                tooltip: "Minimise"
                onClicked: Windows.activeMinimize()
            }
            IconButton {
                width: 30; height: 30; radius: 15; iconSize: 14
                icon: Windows.activeMaximized ? "window-restore-symbolic" : "window-maximize-symbolic"
                symbolic: true
                enabled: root.hasTarget
                tooltip: Windows.activeMaximized ? "Restore" : "Maximise"
                onClicked: Windows.activeToggleMaximize()
            }
            IconButton {
                width: 30; height: 30; radius: 15; iconSize: 14
                icon: "window-close-symbolic"; symbolic: true
                enabled: root.hasTarget
                tooltip: "Close"
                onClicked: Windows.activeClose()
            }
        }
    }
}
