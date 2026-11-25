// Notifications: Do Not Disturb, and clearing what's on screen. The banners
// themselves are mako, styled in Ember.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Notifications"
    lead: "Banners from apps and from Enclave."

    property bool dnd: false
    property bool available: true
    function refresh() {
        System.query("makoctl", ["mode"], (out, code) => {
            page.available = code === 0
            page.dnd = out.split("\n").indexOf("do-not-disturb") >= 0
        })
    }
    Component.onCompleted: refresh()

    Controls.Group {
        note: page.available ? "" : "The notification service isn't running in this session."
        Controls.Field {
            icon: "notifications-disabled-symbolic"
            iconLive: page.dnd
            title: "Do Not Disturb"
            subtitle: page.dnd ? "Banners are held back until you turn this off" : "Banners appear in the corner as they arrive"
            Controls.Switch {
                enabled: page.available
                checked: page.dnd
                onToggled: (on) => System.query("makoctl", ["mode", on ? "-a" : "-r", "do-not-disturb"], () => page.refresh())
            }
        }
        Controls.Field {
            icon: "edit-clear-all-symbolic"
            title: "Clear notifications"
            subtitle: "Dismiss every banner on screen"
            Controls.Button {
                text: "Clear all"
                enabled: page.available
                onClicked: System.query("makoctl", ["dismiss", "--all"], () => {})
            }
        }
        Controls.Field {
            icon: "edit-undo-symbolic"
            title: "Show the last one again"
            Controls.Button {
                text: "Restore"
                enabled: page.available
                onClicked: System.query("makoctl", ["restore"], () => {})
            }
        }
    }

    Controls.Group {
        title: "Try it"
        Controls.Field {
            icon: "preferences-system-notifications-symbolic"
            title: "Send a test notification"
            Controls.Button {
                text: "Send"
                primary: true
                onClicked: System.run("notify-send", ["-a", "Settings", "-i", "preferences-system-notifications", "Hello from Enclave", "This is how notifications look."])
            }
        }
    }
}
