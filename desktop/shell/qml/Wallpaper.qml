// Enclave Shell — desktop background (layer-shell "background" layer).
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave

Window {
    id: root
    visible: true
    color: Theme.c.background
    title: "Enclave Desktop"

    property url source: "file:///usr/share/enclave/wallpapers/enclave-default.svg"

    LayerShell.Window.scope: "enclave-wallpaper"
    LayerShell.Window.layer: LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Ember fallback when no wallpaper is installed: obsidian with a warm glow.
    Rectangle {
        anchors.fill: parent
        visible: image.status !== Image.Ready
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.dark ? "#101114" : "#F7F6F3" }
            GradientStop { position: 1.0; color: Theme.dark ? "#2A1A10" : "#FFE3CC" }
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        cache: false
    }

    // Right-click on the desktop: a quick appearance switch (more to come
    // with the Control Center).
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: Theme.toggleDark()
    }
}
