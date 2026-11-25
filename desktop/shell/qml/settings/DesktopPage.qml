// Desktop & Dock: the dock's behaviour and size, which desktop widgets show,
// and which icons sit on the desktop. Written to shell.conf / the pins file;
// the running shell re-reads them at once.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Desktop & Dock"
    lead: "The dock, the desktop widgets and the icons on your desktop."

    function opt(key, fallback) { return String(System.setting(key, fallback)) }
    function set(key, value) {
        System.setSetting(key, value)
        if (page.settings) page.settings.applied()
    }

    // a little dock that shows the chosen icon size
    Rectangle {
        width: parent.width
        height: 120
        radius: Theme.radius.medium + 2
        color: Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        clip: true
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.85
            sourceSize: Qt.size(800, 240)
            source: "file:///usr/share/enclave/wallpapers/" + (Theme.dark ? "enclave-default.svg" : "enclave-default-light.svg")
        }
        Rectangle {
            id: mini
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            property int s: Number(page.opt("dock/iconSize", 40))
            height: s + 18
            width: miniRow.width + 16
            radius: Theme.radius.large - 4
            color: Theme.c.glass
            border.width: 1
            border.color: Theme.c.border
            Behavior on height { NumberAnimation { duration: Theme.motion.standard } }
            Row {
                id: miniRow
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: Apps.taskbarPins.filter(id => !!Apps.app(id).icon).slice(0, 6)
                    delegate: Image {
                        required property string modelData
                        width: mini.s; height: mini.s
                        sourceSize: Qt.size(mini.s * 2, mini.s * 2)
                        source: Apps.app(modelData).icon ? "image://icon/" + Apps.app(modelData).icon : ""
                    }
                }
                Image {
                    visible: page.opt("dock/trash", true) !== "false"
                    width: mini.s; height: mini.s
                    sourceSize: Qt.size(mini.s * 2, mini.s * 2)
                    source: "image://icon/user-trash"
                }
            }
        }
    }

    Controls.Group {
        title: "Dock"
        Controls.Field {
            icon: "zoom-in-symbolic"
            title: "Icon size"
            Controls.Segmented {
                options: [{ label: "Small", value: 34 }, { label: "Medium", value: 40 }, { label: "Large", value: 46 }]
                value: Number(page.opt("dock/iconSize", 40))
                onPicked: (v) => { page.set("dock/iconSize", v); mini.s = v }
            }
        }
        Controls.Field {
            icon: "view-fullscreen-symbolic"
            title: "Magnify icons under the pointer"
            Controls.Switch {
                checked: page.opt("dock/magnify", true) !== "false"
                onToggled: (on) => page.set("dock/magnify", on)
            }
        }
        Controls.Field {
            icon: "go-bottom-symbolic"
            title: "Hide the dock automatically"
            subtitle: "It comes back when the pointer reaches the bottom edge"
            Controls.Switch {
                checked: page.opt("dock/autohide", false) === "true"
                onToggled: (on) => page.set("dock/autohide", on)
            }
        }
        Controls.Field {
            icon: "user-trash-symbolic"
            title: "Show Trash in the dock"
            Controls.Switch {
                checked: page.opt("dock/trash", true) !== "false"
                onToggled: (on) => page.set("dock/trash", on)
            }
        }
    }

    Controls.Group {
        title: "Desktop widgets"
        Controls.Field {
            icon: "preferences-system-time-symbolic"
            title: "Now"
            subtitle: "The time, date, network and battery"
            Controls.Switch {
                checked: page.opt("desktop/status", true) !== "false"
                onToggled: (on) => page.set("desktop/status", on)
            }
        }
        Controls.Field {
            icon: "system-search-symbolic"
            title: "Search"
            subtitle: "The search bar at the top of the desktop (Super + Space works either way)"
            Controls.Switch {
                checked: page.opt("desktop/search", true) !== "false"
                onToggled: (on) => page.set("desktop/search", on)
            }
        }
        Controls.Field {
            icon: "utilities-system-monitor-symbolic"
            title: "System Overview and Assistant"
            Controls.Switch {
                checked: page.opt("desktop/widgets", true) !== "false"
                onToggled: (on) => page.set("desktop/widgets", on)
            }
        }
    }

    Controls.Group {
        title: "Icons on the desktop"
        Repeater {
            model: [{ id: "home", title: "Home folder", icon: "user-home-symbolic" },
                    { id: "trash", title: "Trash", icon: "user-trash-symbolic" }]
            delegate: Controls.Field {
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                Controls.Switch {
                    checked: Apps.desktopPins.indexOf(modelData.id) >= 0
                    onToggled: (on) => { Apps.pinDesktop(modelData.id, on); if (page.settings) page.settings.applied() }
                }
            }
        }
    }
}
