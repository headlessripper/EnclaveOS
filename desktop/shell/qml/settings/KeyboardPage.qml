// Keyboard: the layout (localectl, applied from the next sign-in) and the
// Enclave shortcuts, drawn as key caps.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Keyboard"
    lead: "Your keyboard layout, and the shortcuts that drive Enclave."

    property string layout: ""
    property string message: ""
    readonly property var layouts: [
        { value: "us", label: "English (US)" }, { value: "gb", label: "English (UK)" },
        { value: "ie", label: "English (Ireland)" }, { value: "de", label: "German" },
        { value: "fr", label: "French" }, { value: "es", label: "Spanish" },
        { value: "it", label: "Italian" }, { value: "pt", label: "Portuguese" },
        { value: "br", label: "Portuguese (Brazil)" }, { value: "nl", label: "Dutch" },
        { value: "se", label: "Swedish" }, { value: "no", label: "Norwegian" },
        { value: "dk", label: "Danish" }, { value: "fi", label: "Finnish" },
        { value: "pl", label: "Polish" }, { value: "cz", label: "Czech" },
        { value: "hu", label: "Hungarian" }, { value: "ro", label: "Romanian" },
        { value: "tr", label: "Turkish" }, { value: "gr", label: "Greek" },
        { value: "ru", label: "Russian" }, { value: "ua", label: "Ukrainian" },
        { value: "ara", label: "Arabic" }, { value: "il", label: "Hebrew" },
        { value: "in", label: "Indian" }, { value: "jp", label: "Japanese" },
        { value: "kr", label: "Korean" }, { value: "cn", label: "Chinese" },
        { value: "ch", label: "Swiss" }, { value: "ca", label: "Canadian (French)" },
        { value: "latam", label: "Spanish (Latin America)" }
    ]
    readonly property var shortcuts: [
        { keys: ["Super"], what: "Open or close Start" },
        { keys: ["Super", "Space"], what: "Search apps, files, settings and the web" },
        { keys: ["Super", "A"], what: "Control Center" },
        { keys: ["Super", "I"], what: "Settings" },
        { keys: ["Super", "E"], what: "Files" },
        { keys: ["Super", "Return"], what: "Terminal" },
        { keys: ["Super", "D"], what: "Show the desktop" },
        { keys: ["Super", "W"], what: "Show or hide the widgets" },
        { keys: ["Super", "←  →"], what: "Snap a window to the left or right half" },
        { keys: ["Super", "↑"], what: "Maximise the window" },
        { keys: ["Alt", "Tab"], what: "Switch windows" },
        { keys: ["Alt", "F4"], what: "Close the window" },
        { keys: ["Ctrl", "Shift", "Esc"], what: "Activity (task manager)" },
        { keys: ["Super", "Shift", "S"], what: "Take a screenshot" },
        { keys: ["Super", "L"], what: "Lock the screen" }
    ]

    Component.onCompleted: System.query("localectl", ["status"], (out) => {
        const m = /X11 Layout:\s*(\S+)/.exec(out)
        page.layout = m ? m[1].split(",")[0] : "us"
    })

    Controls.Group {
        title: "Layout"
        note: page.message !== "" ? page.message : "A new layout takes effect the next time you sign in."
        Controls.Field {
            icon: "input-keyboard-symbolic"
            title: "Keyboard layout"
            subtitle: (page.layouts.find(l => l.value === page.layout) || { label: page.layout }).label
            Controls.Choice {
                options: page.layouts
                value: page.layout
                onPicked: (v) => System.query("localectl", ["set-x11-keymap", v], (out, code) => {
                    page.message = code === 0 ? "Saved — sign out and back in to use it." : "Couldn't change the layout — it needs administrator approval."
                    if (code === 0) page.layout = v
                }, 60000)
            }
        }
    }

    Controls.Group {
        title: "Shortcuts"
        Repeater {
            model: page.shortcuts
            delegate: Controls.Field {
                required property var modelData
                height: 44
                title: modelData.what
                Row {
                    spacing: 4
                    Repeater {
                        model: modelData.keys
                        delegate: Rectangle {
                            required property string modelData
                            height: 24
                            width: Math.max(26, capText.implicitWidth + 16)
                            radius: 6
                            color: Theme.c.elevated
                            border.width: 1
                            border.color: Theme.c.border
                            Rectangle {     // the key's lower lip
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 2; radius: 6
                                color: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.08)
                            }
                            Text {
                                id: capText
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                text: modelData
                                color: Theme.c.text
                                font.pointSize: 8.5
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }
}
