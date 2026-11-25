// Enclave Shell — the desktop: wallpaper (layer-shell "background" layer),
// optional icons down the left (none by default; click to select,
// double-click to open, right-click to remove) and a right-click menu.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: true
    color: Theme.c.background
    title: "Enclave Desktop"

    // Ember Horizon, in the light or dark cut (tools/make-wallpapers.py), or
    // a picture chosen in Settings → Appearance
    property string custom: String(System.setting("desktop/wallpaper", ""))
    property url source: custom !== "" ? "file://" + custom
                         : "file:///usr/share/enclave/wallpapers/"
                           + (Theme.dark ? "enclave-default.svg" : "enclave-default-light.svg")
    signal controlCenterRequested()
    signal widgetsToggled()
    signal statusToggled()
    signal searchWidgetToggled()
    property bool widgetsShown: true
    property bool statusShown: true
    property bool searchShown: true

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
            GradientStop { position: 0.0; color: Theme.c.background }
            GradientStop { position: 1.0; color: Theme.dark ? Qt.tint(Theme.c.background, Qt.alpha(Theme.brand.burnt, 0.18))
                                                            : Theme.brand.glow }
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

    property string selected: ""

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (point, button) => {
            root.selected = ""
            if (button === Qt.RightButton)
                desktopMenu.popup()
        }
    }

    // ---- desktop icons: none by default; added from Start, the dock or the
    // desktop menu (Home, Trash), removed from their own right-click menu ----
    readonly property var shortcuts: Apps.desktopPins.map(id => {
        if (id === "home")
            return { id: id, label: "Home", icon: "user-home", run: () => System.run("thunar", [System.homePath]) }
        if (id === "trash")
            return { id: id, label: "Trash", icon: "user-trash", run: () => System.run("thunar", ["trash:///"]) }
        const a = Apps.app(id)
        return a.appId ? { id: id, label: a.name, icon: a.icon, run: () => Apps.launch(id) } : null
    }).filter(s => s !== null)

    Grid {
        x: 16
        y: 20
        flow: Grid.TopToBottom
        rows: Math.max(1, Math.floor((root.height - y - Theme.taskbarHeight - 8) / 94))
        rowSpacing: 6
        columnSpacing: 6
        Repeater {
            model: root.shortcuts
            delegate: Item {
                id: sc
                required property var modelData
                readonly property bool isSelected: root.selected === modelData.id
                width: 92; height: 88
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.medium
                    color: sc.isSelected ? Theme.c.accentSoft : scMouse.containsMouse ? Qt.alpha(Theme.c.glass, 0.45) : "transparent"
                    border.width: sc.isSelected ? 1 : 0
                    border.color: Qt.alpha(Theme.c.accent, 0.6)
                }
                Image {
                    id: scIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: 44; height: 44
                    sourceSize: Qt.size(88, 88)
                    source: "image://icon/" + sc.modelData.icon
                    scale: scMouse.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.motion.fast } }
                }
                Text {
                    anchors { top: scIcon.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: sc.modelData.label
                    // light text with a soft shadow reads on any wallpaper
                    color: "white"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                    font.pointSize: 9
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: scMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (e) => {
                        root.selected = sc.modelData.id
                        if (e.button === Qt.RightButton) {
                            iconMenu.target = sc.modelData
                            iconMenu.popup()
                        }
                    }
                    onDoubleClicked: (e) => {
                        if (e.button !== Qt.LeftButton) return
                        root.selected = ""
                        sc.modelData.run()
                    }
                }
            }
        }
    }

    EmberMenu {
        id: iconMenu
        property var target: null
        MenuItem { text: "Open"; onTriggered: if (iconMenu.target) iconMenu.target.run() }
        MenuSeparator {}
        MenuItem {
            text: "Remove from desktop"
            onTriggered: if (iconMenu.target) Apps.pinDesktop(iconMenu.target.id, false)
        }
    }

    EmberMenu {
        id: desktopMenu
        MenuItem { text: Theme.dark ? "Switch to light" : "Switch to dark"; onTriggered: Theme.toggleDark() }
        MenuItem { text: "Clock & status"; checkable: true; checked: root.statusShown; onTriggered: root.statusToggled() }
        MenuItem { text: "Search"; checkable: true; checked: root.searchShown; onTriggered: root.searchWidgetToggled() }
        MenuItem { text: "Widgets"; checkable: true; checked: root.widgetsShown; onTriggered: root.widgetsToggled() }
        MenuSeparator {}
        MenuItem {
            text: "Show Home on desktop"
            checkable: true
            checked: Apps.desktopPins.indexOf("home") >= 0
            onTriggered: Apps.pinDesktop("home", checked)
        }
        MenuItem {
            text: "Show Trash on desktop"
            checkable: true
            checked: Apps.desktopPins.indexOf("trash") >= 0
            onTriggered: Apps.pinDesktop("trash", checked)
        }
        MenuSeparator {}
        MenuItem { text: "Open Terminal"; onTriggered: System.run("enclave-terminal", ["--working-directory", System.homePath + "/Desktop"]) }
        MenuItem { text: "Display settings"; onTriggered: System.run("enclave-settings", ["--page", "displays"]) }
        MenuItem { text: "Personalise"; onTriggered: System.run("enclave-settings", ["--page", "appearance"]) }
        MenuItem { text: "Quick settings"; onTriggered: root.controlCenterRequested() }
    }
}
