// Appearance: light, dark or automatic (each shown as a little desktop), the
// wallpaper (Ember Horizon, or a picture from your Pictures folder) and
// reduced motion. Written to shell.conf; the shell is told at once.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Appearance"
    lead: "How Enclave looks — the same Ember colours, in light or dark."

    property string wallpaper: String(System.setting("desktop/wallpaper", ""))
    property var pictures: []

    function setMode(m) {
        Theme.mode = m
        if (page.settings) page.settings.applied()
    }
    function setWallpaper(path) {
        page.wallpaper = path
        System.setSetting("desktop/wallpaper", path)
        if (page.settings) page.settings.applied()
    }
    Component.onCompleted: System.query("sh", ["-c",
        "find \"$HOME/Pictures\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.svg' \\) 2>/dev/null | head -n 11"],
        (out) => page.pictures = out.split("\n").filter(l => l))

    // a tiny desktop in the given palette
    component Preview: Rectangle {
        id: pv
        property string mode: "light"
        property string label: ""
        signal picked(string mode)
        readonly property bool on: Theme.mode === mode
        readonly property bool darkCut: mode === "dark"
        width: 196; height: 160
        radius: Theme.radius.medium + 2
        color: "transparent"
        border.width: on ? 2 : 1
        border.color: on ? Theme.c.accent : Theme.c.border
        Rectangle {
            id: screenArea
            x: 8; y: 8
            width: parent.width - 16; height: 110
            radius: Theme.radius.medium - 2
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: pv.darkCut ? "#101114" : "#F7F6F3" }
                GradientStop { position: 0.75; color: pv.darkCut ? "#2A1A12" : "#FFE3CC" }
                GradientStop { position: 1; color: pv.darkCut ? "#E95B16" : "#FFAC55" }
            }
            // split preview for Automatic
            Rectangle {
                visible: pv.mode === "system"
                x: parent.width / 2; width: parent.width / 2; height: parent.height
                gradient: Gradient {
                    GradientStop { position: 0; color: "#101114" }
                    GradientStop { position: 0.75; color: "#2A1A12" }
                    GradientStop { position: 1; color: "#E95B16" }
                }
            }
            // a window
            Rectangle {
                x: 14; y: 14; width: 92; height: 60; radius: 6
                color: pv.darkCut ? "#1A1C21" : "#FFFFFF"
                border.width: 1
                border.color: pv.darkCut ? "#14FFFFFF" : "#1A000000"
                Rectangle { x: 8; y: 10; width: 46; height: 5; radius: 2.5; color: pv.darkCut ? "#F5F3EF" : "#202124"; opacity: 0.8 }
                Rectangle { x: 8; y: 21; width: 70; height: 4; radius: 2; color: pv.darkCut ? "#A7A39B" : "#6B6860"; opacity: 0.6 }
                Rectangle { x: 8; y: 31; width: 58; height: 4; radius: 2; color: pv.darkCut ? "#A7A39B" : "#6B6860"; opacity: 0.6 }
                Rectangle { x: 8; y: 44; width: 28; height: 9; radius: 4.5; color: "#FF7A1A" }
            }
            // the dock
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: 86; height: 14; radius: 5
                color: pv.darkCut ? "#F51A1C21" : "#F7F7F6F3"
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: 5
                        Rectangle { width: 8; height: 8; radius: 2.5; color: index === 1 ? "#FF7A1A" : (pv.darkCut ? "#3A3D45" : "#D9D6CF") }
                    }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: screenArea.y + screenArea.height + 10
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: pv.on ? Theme.c.accent : "transparent"
                border.width: pv.on ? 0 : 1.5
                border.color: Theme.c.textSecondary
                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: "white"; visible: pv.on }
            }
            Text {
                text: pv.label
                color: Theme.c.text
                font.pointSize: 9.5
                font.weight: pv.on ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pv.picked(pv.mode) }
    }

    Controls.Group {
        title: "Appearance"
        Item {
            width: parent.width
            height: 192
            Row {
                anchors.centerIn: parent
                spacing: 18
                Preview { mode: "light"; label: "Light"; onPicked: (m) => page.setMode(m) }
                Preview { mode: "dark"; label: "Dark"; onPicked: (m) => page.setMode(m) }
                Preview { mode: "system"; label: "Automatic"; onPicked: (m) => page.setMode(m) }
            }
        }
    }

    Controls.Group {
        title: "Wallpaper"
        note: page.pictures.length === 0 ? "Put pictures in your Pictures folder to use them as wallpaper." : ""
        Flow {
            width: parent.width
            padding: 14
            spacing: 12
            // Ember Horizon (follows light / dark)
            Rectangle {
                width: 128; height: 80
                radius: Theme.radius.small + 3
                border.width: page.wallpaper === "" ? 2 : 1
                border.color: page.wallpaper === "" ? Theme.c.accent : Theme.c.border
                color: "transparent"
                Image {
                    anchors.fill: parent; anchors.margins: 3
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 160)
                    source: "file:///usr/share/enclave/wallpapers/" + (Theme.dark ? "enclave-default.svg" : "enclave-default-light.svg")
                }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                    text: "Ember Horizon"
                    color: "white"
                    font.pointSize: 8
                    font.weight: Font.DemiBold
                    style: Text.Raised; styleColor: "#80000000"
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.setWallpaper("") }
            }
            Repeater {
                model: page.pictures
                delegate: Rectangle {
                    required property string modelData
                    width: 128; height: 80
                    radius: Theme.radius.small + 3
                    color: "transparent"
                    border.width: page.wallpaper === modelData ? 2 : 1
                    border.color: page.wallpaper === modelData ? Theme.c.accent : Theme.c.border
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(256, 160)
                        source: "file://" + parent.modelData
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.setWallpaper(parent.modelData) }
                }
            }
        }
    }

    Controls.Group {
        title: "Motion & icons"
        Controls.Field {
            icon: "preferences-desktop-accessibility-symbolic"
            title: "Reduce motion"
            subtitle: "Calmer animations: no magnifying dock, no bounce"
            Controls.Switch {
                checked: Theme.reducedMotion
                onToggled: (on) => { Theme.reducedMotion = on; if (page.settings) page.settings.applied() }
            }
        }
        Controls.Field {
            icon: "preferences-desktop-icons-symbolic"
            title: "Icons"
            subtitle: "Enclave Icons; other apps keep their own"
            Text {
                text: Theme.iconTheme
                color: Theme.c.textSecondary
                font.pointSize: 9
            }
        }
    }
}
