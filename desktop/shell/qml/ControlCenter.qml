// Enclave Shell — Control Center (quick settings), dropped from the top bar status
// icons, the bubble, Super+A or the Settings app entry. Laid out like
// macOS's: a connectivity module and appearance tiles side by side, sound
// below, then the account and power row. Orange only marks what is on.
import QtQuick
import QtQuick.Controls
import Enclave
import "components"

Flyout {
    id: root
    scope: "enclave-control-center"
    title: "Enclave Control Center"
    panelWidth: 360

    property Status status
    onShownChanged: if (status) status.fast = shown
    onAboutToOpen: if (status) status.refresh()

    function runLater(cmd) {
        root.close()
        System.run("sh", ["-c", "sleep 0.3; exec " + cmd])
    }

    Column {
        width: parent.width
        spacing: 10

        // ---- connectivity + appearance ----
        Row {
            width: parent.width
            spacing: 10

            Module {
                width: (parent.width - 10) / 2 + 14
                height: 140
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3
                    ToggleRow {
                        width: parent.width
                        icon: root.status ? root.status.netIcon : "network-offline-symbolic"
                        title: root.status && root.status.netType === "ethernet" ? "Ethernet" : "Wi-Fi"
                        subtitle: root.status ? root.status.netLabel : ""
                        on: !!root.status && (root.status.netType !== "none"
                                              || (root.status.hasWifi && root.status.wifiOn))
                        onToggled: if (root.status && root.status.hasWifi) root.status.toggleWifi()
                        onOpened: root.runLater("nm-connection-editor")
                    }
                    ToggleRow {
                        width: parent.width
                        icon: "notifications-disabled-symbolic"
                        title: "Do Not Disturb"
                        subtitle: on ? "On" : "Off"
                        on: !!root.status && root.status.dnd
                        onToggled: if (root.status) root.status.toggleDnd()
                        onOpened: toggled()
                    }
                    ToggleRow {
                        width: parent.width
                        icon: "preferences-desktop-accessibility-symbolic"
                        title: "Reduce motion"
                        subtitle: on ? "On" : "Off"
                        on: Theme.reducedMotion
                        onToggled: Theme.reducedMotion = !Theme.reducedMotion
                        onOpened: toggled()
                    }
                }
            }

            Column {
                width: (parent.width - 10) / 2 - 14
                spacing: 10

                Module {
                    width: parent.width
                    height: 65
                    ToggleRow {
                        anchors.fill: parent
                        anchors.margins: 10
                        icon: Theme.dark ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
                        title: "Dark Mode"
                        subtitle: Theme.mode === "system" ? "Automatic" : (Theme.dark ? "On" : "Off")
                        on: Theme.dark
                        onToggled: Theme.toggleDark()
                        onOpened: toggled()
                    }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            { label: "Screenshot", icon: "camera-photo-symbolic", cmd: "enclave-screenshot" },
                            { label: "Displays", icon: "video-display-symbolic", cmd: "wdisplays" },
                        ]
                        delegate: Module {
                            id: tile
                            required property var modelData
                            width: (parent.width - 10) / 2
                            height: 65
                            color: tileMouse.containsMouse ? (Theme.dark ? Qt.lighter(Theme.c.elevated, 1.15)
                                                                         : Theme.c.background)
                                                           : (Theme.dark ? Theme.c.elevated : Theme.c.surface)
                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 18; height: 18
                                    sourceSize: Qt.size(36, 36)
                                    source: "image://icon/" + tile.modelData.icon + "?color=" + encodeURIComponent(Theme.c.text)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.modelData.label
                                    color: Theme.c.text
                                    font.pointSize: 8.5
                                }
                            }
                            MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: root.runLater(tile.modelData.cmd) }
                        }
                    }
                }
            }
        }

        // ---- sound ----
        Module {
            width: parent.width
            height: 70
            visible: !!root.status && root.status.hasAudio
            Text {
                x: 12; y: 9
                text: "Sound"
                color: Theme.c.text
                font.pointSize: 9.5
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 9
                text: root.status ? (root.status.muted ? "Muted" : Math.round(root.status.volume * 100) + "%") : ""
                color: Theme.c.textSecondary
                font.pointSize: 8.5
            }
            Row {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 10 }
                spacing: 8
                EmberSlider {
                    width: parent.width - mute.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.status ? root.status.volumeIcon : ""
                    value: root.status ? root.status.volume : 0
                    onPressedChanged: if (root.status) root.status.volumeDrag = pressed
                    onMoved: if (root.status) root.status.setVolume(value)
                }
                IconButton {
                    id: mute
                    width: 28; height: 28
                    radius: 14
                    iconSize: 14
                    symbolic: true
                    icon: "audio-speakers-symbolic"
                    tooltip: "Sound settings"
                    onClicked: root.runLater("pavucontrol")
                }
            }
        }

        // ---- account and power ----
        Item {
            width: parent.width
            height: 36
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: Theme.c.accentSoft
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        visible: System.avatar === ""
                        text: System.userInitial
                        color: Theme.c.accent
                        font.weight: Font.DemiBold
                    }
                    Image {
                        anchors.fill: parent
                        visible: System.avatar !== ""
                        source: System.avatar !== "" ? "file://" + System.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: System.userName; color: Theme.c.text; font.pointSize: 9.5; font.weight: Font.DemiBold }
                    Text {
                        visible: !!root.status && root.status.battery >= 0
                        text: root.status ? "Battery " + root.status.battery + "%"
                                            + (root.status.charging ? " · charging" : "") : ""
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                IconButton {
                    width: 32; height: 32; radius: 16; iconSize: 16; symbolic: true
                    icon: "system-lock-screen-symbolic"; tooltip: "Lock"
                    onClicked: { root.close(); System.lock() }
                }
                IconButton {
                    id: powerButton
                    width: 32; height: 32; radius: 16; iconSize: 16; symbolic: true
                    icon: "system-shutdown-symbolic"; tooltip: "Power"
                    onClicked: powerMenu.popup(powerButton, 0, -powerMenu.implicitHeight - 6)
                }
                EmberMenu {
                    id: powerMenu
                    MenuItem { text: "Sleep"; onTriggered: { root.close(); System.suspend() } }
                    MenuItem { text: "Restart"; onTriggered: System.reboot() }
                    MenuItem { text: "Shut down"; onTriggered: System.powerOff() }
                    MenuSeparator {}
                    MenuItem { text: "Sign out"; onTriggered: System.logout() }
                }
            }
        }
    }
}
