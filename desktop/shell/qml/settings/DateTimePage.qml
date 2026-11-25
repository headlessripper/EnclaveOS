// Date & Time: the clock, setting time automatically (NTP), and the time
// zone, picked from a searchable list. systemd's timedatectl underneath.
import QtQuick
import QtQuick.Controls as T
import Enclave

Controls.Page {
    id: page
    title: "Date & Time"
    lead: "The clock, and where in the world this computer is."

    property date now: new Date()
    property string zone: ""
    property bool ntp: false
    property bool synced: false
    property var zones: []
    property string message: ""

    function refresh() {
        System.query("timedatectl", ["show"], (out, code) => {
            if (code !== 0)       // no systemd-timedated: read the zone off /etc/localtime
                System.query("readlink", ["/etc/localtime"], (l) => page.zone = l.split("zoneinfo/").pop())
            for (const l of out.split("\n")) {
                const i = l.indexOf("=")
                const k = l.slice(0, i), v = l.slice(i + 1)
                if (k === "Timezone") page.zone = v
                else if (k === "NTP") page.ntp = v === "yes"
                else if (k === "NTPSynchronized") page.synced = v === "yes"
            }
        })
    }
    Component.onCompleted: {
        refresh()
        System.query("sh", ["-c", "timedatectl list-timezones 2>/dev/null || (cd /usr/share/zoneinfo && find . -type f -name '[A-Z]*' | sed 's|^./||' | grep -E '^(Africa|America|Antarctica|Asia|Atlantic|Australia|Europe|Indian|Pacific)/' | sort)"],
                     (out) => page.zones = out.split("\n").filter(z => z), 6000)
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: page.now = new Date() }

    // the clock
    Rectangle {
        width: parent.width
        height: 130
        radius: Theme.radius.medium + 2
        color: Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        Canvas {
            id: face
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 96; height: 96
            property int sec: page.now.getSeconds()
            onSecChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const c = width / 2, r = c - 3
                ctx.lineWidth = 2
                ctx.strokeStyle = Qt.color(Theme.c.border)
                ctx.fillStyle = Qt.color(Theme.c.hover)
                ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.fill(); ctx.stroke()
                for (let i = 0; i < 12; ++i) {
                    const a = i * Math.PI / 6
                    ctx.beginPath()
                    ctx.moveTo(c + Math.cos(a) * (r - 4), c + Math.sin(a) * (r - 4))
                    ctx.lineTo(c + Math.cos(a) * (r - (i % 3 ? 8 : 11)), c + Math.sin(a) * (r - (i % 3 ? 8 : 11)))
                    ctx.strokeStyle = Qt.color(Theme.c.textSecondary)
                    ctx.lineWidth = i % 3 ? 1 : 2
                    ctx.stroke()
                }
                const t = page.now
                const hand = (angle, len, w, col) => {
                    ctx.beginPath(); ctx.lineCap = "round"; ctx.lineWidth = w; ctx.strokeStyle = col
                    ctx.moveTo(c, c); ctx.lineTo(c + Math.cos(angle) * len, c + Math.sin(angle) * len); ctx.stroke()
                }
                hand(((t.getHours() % 12) + t.getMinutes() / 60) * Math.PI / 6 - Math.PI / 2, r * 0.5, 3.5, Qt.color(Theme.c.text))
                hand((t.getMinutes() + t.getSeconds() / 60) * Math.PI / 30 - Math.PI / 2, r * 0.72, 2.5, Qt.color(Theme.c.text))
                hand(t.getSeconds() * Math.PI / 30 - Math.PI / 2, r * 0.8, 1.2, Qt.color(Theme.c.accent))
                ctx.fillStyle = Qt.color(Theme.c.accent)
                ctx.beginPath(); ctx.arc(c, c, 3, 0, 2 * Math.PI); ctx.fill()
            }
        }
        Column {
            anchors { left: face.right; leftMargin: 24; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                text: Qt.formatTime(page.now, "HH:mm")
                color: Theme.c.text
                font.pointSize: 28
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Text {
                text: Qt.formatDate(page.now, "dddd, d MMMM yyyy")
                color: Theme.c.text
                font.pointSize: 10.5
            }
            Text {
                text: page.zone.replace(/_/g, " ")
                color: Theme.c.textSecondary
                font.pointSize: 9
            }
        }
    }

    Controls.Group {
        note: page.message
        Controls.Field {
            icon: "emblem-synchronizing-symbolic"
            iconLive: page.ntp && page.synced
            title: "Set the time automatically"
            subtitle: page.ntp ? (page.synced ? "In step with internet time" : "Waiting for internet time…") : "Off"
            Controls.Switch {
                checked: page.ntp
                onToggled: (on) => System.query("timedatectl", ["set-ntp", on ? "true" : "false"], (out, code) => {
                    page.message = code === 0 ? "" : "Couldn't change that — it needs administrator approval."
                    page.refresh()
                }, 60000)
            }
        }
    }

    Controls.Group {
        title: "Time zone"
        Item {
            width: parent.width
            height: 290
            Controls.Input {
                id: zoneFilter
                x: 14; y: 14
                width: parent.width - 28
                placeholderText: "Search cities and regions — e.g. London, Lagos, Tokyo"
            }
            ListView {
                id: zoneList
                x: 8
                anchors { top: zoneFilter.bottom; topMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
                width: parent.width - 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                T.ScrollBar.vertical: T.ScrollBar {}
                model: {
                    const q = zoneFilter.text.trim().toLowerCase().replace(/ /g, "_")
                    const list = q === "" ? page.zones : page.zones.filter(z => z.toLowerCase().indexOf(q) >= 0)
                    return list.slice(0, 200)
                }
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool on: modelData === page.zone
                    width: zoneList.width
                    height: 32
                    radius: Theme.radius.small + 2
                    color: on ? Theme.c.accentSoft : zoneMouse.containsMouse ? Theme.c.hover : "transparent"
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.split("/").pop().replace(/_/g, " ")
                        color: Theme.c.text
                        font.pointSize: 9.5
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.split("/").slice(0, -1).join(" / ").replace(/_/g, " ")
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                    }
                    MouseArea {
                        id: zoneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: System.query("timedatectl", ["set-timezone", modelData], (out, code) => {
                            page.message = code === 0 ? "" : "Couldn't change the time zone — it needs administrator approval."
                            page.refresh()
                        }, 60000)
                    }
                }
            }
        }
    }
}
