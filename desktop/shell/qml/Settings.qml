// Enclave Settings — one window for every system page: a sidebar (you, a
// search, the sections) and the page. Runs as `enclave-settings [--page id]`
// (enclave-shell --settings). Changes that the desktop shows (appearance, the
// dock, desktop widgets) are written to shell.conf and the running shell is
// told to re-read them, so they apply at once.
import QtQuick
import QtQuick.Window
import Enclave
import "components"
import "settings"

Window {
    id: win
    visible: true
    width: 1040
    height: 700
    minimumWidth: 760
    minimumHeight: 480
    title: "Settings"
    color: Theme.c.background

    property string page: "network"

    readonly property var sections: [
        { id: "network",       title: "Network",         icon: "network-wireless-symbolic", group: 0,
          keys: "wifi wi-fi ethernet internet ip airplane hostname" },
        { id: "sound",         title: "Sound",           icon: "audio-volume-high-symbolic", group: 0,
          keys: "volume speaker headphones microphone input output mute" },
        { id: "displays",      title: "Displays",        icon: "video-display-symbolic", group: 0,
          keys: "monitor screen resolution scale refresh rate" },
        { id: "appearance",    title: "Appearance",      icon: "applications-graphics-symbolic", group: 1,
          keys: "dark light theme wallpaper background motion animation" },
        { id: "desktop",       title: "Desktop & Dock",  icon: "user-desktop-symbolic", group: 1,
          keys: "dock taskbar widgets search clock magnify hide trash icons" },
        { id: "notifications", title: "Notifications",   icon: "preferences-system-notifications-symbolic", group: 1,
          keys: "do not disturb dnd alerts banners" },
        { id: "power",         title: "Power & Battery", icon: "battery-good-symbolic", group: 2,
          keys: "battery sleep shut down restart lock power mode profile" },
        { id: "activity",      title: "Activity",        icon: "utilities-system-monitor-symbolic", group: 2,
          keys: "task manager processes cpu memory end quit kill" },
        { id: "storage",       title: "Storage",         icon: "drive-harddisk-symbolic", group: 2,
          keys: "disk space drive free trash" },
        { id: "datetime",      title: "Date & Time",     icon: "preferences-system-time-symbolic", group: 3,
          keys: "clock time zone timezone date ntp" },
        { id: "keyboard",      title: "Keyboard",        icon: "input-keyboard-symbolic", group: 3,
          keys: "layout language shortcuts keys" },
        { id: "about",         title: "About",           icon: "help-about-symbolic", group: 3,
          keys: "version system computer processor memory kernel" }
    ]
    readonly property var pageFiles: ({
        network: "NetworkPage", sound: "SoundPage", displays: "DisplaysPage",
        appearance: "AppearancePage", desktop: "DesktopPage", notifications: "NotificationsPage",
        power: "PowerPage", activity: "ActivityPage", apps: "ActivityPage", storage: "StoragePage",
        datetime: "DateTimePage", keyboard: "KeyboardPage", about: "AboutPage"
    })
    readonly property string current: pageFiles[page] ? (page === "apps" ? "activity" : page) : "network"

    // tell the running shell to re-read shell.conf
    function applied() { System.shellCommand("reload-settings") }

    Shortcut { sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }
    Shortcut { sequences: [StandardKey.Close, "Ctrl+Q"]; onActivated: Qt.quit() }

    // ---------------- sidebar ----------------
    Rectangle {
        id: sidebar
        width: 260
        height: parent.height
        color: Theme.dark ? Theme.c.surface : Qt.darker(Theme.c.background, 1.025)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.c.border }

        Column {
            id: sideHead
            x: 14; y: 18
            width: parent.width - 28
            spacing: 14

            // you
            Rectangle {
                width: parent.width
                height: 62
                radius: Theme.radius.medium + 2
                color: youMouse.containsMouse ? Theme.c.hover : "transparent"
                Rectangle {
                    id: avatar
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.brand.solar }
                        GradientStop { position: 1; color: Theme.brand.burnt }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: System.avatar === ""
                        text: System.userInitial
                        color: "white"
                        font.pointSize: 15
                        font.weight: Font.DemiBold
                    }
                    Image {
                        anchors.fill: parent
                        visible: System.avatar !== ""
                        source: System.avatar === "" ? "" : "file://" + System.avatar
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Column {
                    anchors { left: avatar.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width
                        text: System.userName
                        color: Theme.c.text
                        font.pointSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: System.live ? "Live session" : "Local account"
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                    }
                }
                MouseArea { id: youMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.page = "about" }
            }

            SearchField {
                id: search
                width: parent.width
                implicitHeight: 34
                placeholderText: "Search settings"
                font.pointSize: 9.5
                Keys.onReturnPressed: if (nav.matches.length) win.page = nav.matches[0].id
            }
        }

        ListView {
            id: nav
            anchors { top: sideHead.bottom; topMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
            x: 10
            width: parent.width - 20
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            readonly property var matches: {
                const q = search.text.trim().toLowerCase()
                if (q === "") return win.sections
                return win.sections.filter(s => (s.title + " " + s.keys).toLowerCase().indexOf(q) >= 0)
            }
            model: matches
            delegate: Item {
                id: navItem
                required property var modelData
                required property int index
                readonly property bool on: win.current === modelData.id
                readonly property bool gapAbove: index > 0 && nav.matches[index - 1].group !== modelData.group
                width: nav.width
                height: 38 + (gapAbove ? 12 : 0)
                Rectangle {
                    y: navItem.gapAbove ? 12 : 0
                    width: parent.width
                    height: 38
                    radius: Theme.radius.small + 3
                    color: navItem.on ? Theme.c.accentSoft : navMouse.containsMouse ? Theme.c.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                    Controls.Tile {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        size: 26
                        icon: navItem.modelData.icon
                        live: navItem.on
                    }
                    Text {
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        text: navItem.modelData.title
                        color: Theme.c.text
                        font.pointSize: 10
                        font.weight: navItem.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.page = navItem.modelData.id
                    }
                }
            }
            Text {
                visible: nav.count === 0
                x: 10; y: 6
                text: "No settings match “" + search.text + "”"
                color: Theme.c.textSecondary
                font.pointSize: 9
            }
        }
    }

    // ---------------- the page ----------------
    Loader {
        id: pageLoader
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        source: "settings/" + win.pageFiles[win.current] + ".qml"
        opacity: status === Loader.Ready ? 1 : 0
        onLoaded: if (item) { item.settings = win; fade.restart() }
        NumberAnimation { id: fade; target: pageLoader.item; property: "opacity"; from: 0; to: 1; duration: Theme.motion.standard }
    }
}
