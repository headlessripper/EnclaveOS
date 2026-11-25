// Power & Battery: charge (a ring, health, time left), the power mode
// (power-profiles-daemon, when installed), and lock / sleep / restart /
// shut down.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Power & Battery"
    lead: "Battery, power mode, and turning the computer off."

    property int battery: -1
    property string status: ""
    property int minutes: -1
    property int health: -1
    property string profile: ""
    property var profiles: []

    function refresh() {
        System.query("sh", ["-c",
            "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] || continue; " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$(cat $b/capacity 2>/dev/null)\" \"$(cat $b/status 2>/dev/null)\" " +
            "\"$(cat $b/energy_now $b/charge_now 2>/dev/null | head -n1)\" \"$(cat $b/energy_full $b/charge_full 2>/dev/null | head -n1)\" " +
            "\"$(cat $b/energy_full_design $b/charge_full_design 2>/dev/null | head -n1)\" \"$(cat $b/power_now $b/current_now 2>/dev/null | head -n1)\" x x; break; done"], (out) => {
                const f = out.split("|")
                if (f.length < 6 || f[0] === "") { page.battery = -1; return }
                page.battery = Number(f[0])
                page.status = f[1]
                const now = Number(f[2]), full = Number(f[3]), design = Number(f[4]), rate = Number(f[5])
                page.health = design > 0 && full > 0 ? Math.round(full / design * 100) : -1
                page.minutes = rate > 0 ? Math.round(((f[1] === "Charging" ? full - now : now) / rate) * 60) : -1
            })
        System.query("powerprofilesctl", ["get"], (out, code) => page.profile = code === 0 ? out : "")
        System.query("powerprofilesctl", ["list"], (out, code) => {
            page.profiles = code !== 0 ? [] : out.split("\n").map(l => /^\s*\*?\s*([a-z-]+):\s*$/.exec(l)).filter(m => m).map(m => m[1])
        })
    }
    function duration(m) {
        const h = Math.floor(m / 60), r = m % 60
        return h > 0 ? h + " h " + (r > 0 ? r + " min" : "") : r + " min"
    }
    Component.onCompleted: refresh()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: page.refresh() }

    Controls.Group {
        visible: page.battery >= 0
        Item {
            width: parent.width
            height: 140
            Canvas {
                id: ring
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 104; height: 104
                readonly property real level: page.battery / 100
                readonly property color tone: page.status === "Charging" ? Theme.status.success
                                            : level <= 0.15 ? Theme.status.danger : Theme.c.accent
                onLevelChanged: requestPaint()
                onToneChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, r = c - 6
                    ctx.lineWidth = 9
                    ctx.strokeStyle = Qt.color(Theme.c.pressed)
                    ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke()
                    ctx.lineCap = "round"
                    ctx.strokeStyle = Qt.color(tone)
                    ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * level); ctx.stroke()
                }
                Text {
                    anchors.centerIn: parent
                    text: page.battery + "%"
                    color: Theme.c.text
                    font.pointSize: 17
                    font.weight: Font.DemiBold
                }
            }
            Column {
                anchors { left: ring.right; leftMargin: 26; verticalCenter: parent.verticalCenter }
                spacing: 6
                Text {
                    text: page.status === "Charging" ? "Charging" : page.status === "Full" ? "Fully charged" : "On battery"
                    color: Theme.c.text
                    font.pointSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: page.minutes > 0 ? (page.status === "Charging" ? "Full in " + page.duration(page.minutes)
                                                                         : page.duration(page.minutes) + " left")
                                           : "Working out the time left…"
                    color: Theme.c.textSecondary
                    font.pointSize: 9.5
                }
                Text {
                    visible: page.health > 0
                    text: "Battery health " + Math.min(100, page.health) + "%"
                    color: Theme.c.textSecondary
                    font.pointSize: 9.5
                }
            }
        }
    }

    Controls.Group {
        visible: page.battery < 0
        Controls.Field {
            icon: "ac-adapter-symbolic"
            iconLive: true
            title: "Plugged in"
            subtitle: "This computer runs on mains power"
        }
    }

    Controls.Group {
        title: "Power mode"
        visible: page.profiles.length > 0
        note: "Balanced suits most people. Power saver stretches the battery; Performance keeps fans busier."
        Controls.Field {
            icon: "power-profile-balanced-symbolic"
            title: "Mode"
            Controls.Segmented {
                options: page.profiles.map(p => ({ value: p, label: p === "power-saver" ? "Power saver" : p === "performance" ? "Performance" : "Balanced" }))
                value: page.profile
                onPicked: (v) => System.query("powerprofilesctl", ["set", v], () => page.refresh())
            }
        }
    }

    Controls.Group {
        title: "Turn off"
        Item {
            width: parent.width
            height: 104
            Row {
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: [
                        { label: "Lock", icon: "system-lock-screen-symbolic", act: "lock" },
                        { label: "Sleep", icon: "weather-clear-night-symbolic", act: "suspend" },
                        { label: "Restart", icon: "system-reboot-symbolic", act: "reboot" },
                        { label: "Shut down", icon: "system-shutdown-symbolic", act: "powerOff" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 128; height: 76
                        radius: Theme.radius.medium
                        color: powMouse.pressed ? Theme.c.pressed : powMouse.containsMouse ? Theme.c.hover : "transparent"
                        border.width: 1
                        border.color: Theme.c.border
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Controls.Tile {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: modelData.icon
                                live: powMouse.containsMouse && modelData.label === "Shut down"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Theme.c.text
                                font.pointSize: 9.5
                            }
                        }
                        MouseArea { id: powMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: System[modelData.act]() }
                    }
                }
            }
        }
    }
}
