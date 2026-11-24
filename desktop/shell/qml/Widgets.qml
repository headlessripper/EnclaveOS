// Enclave Shell — desktop widgets, stacked on the right of the desktop (below
// windows, above the wallpaper): System Overview (CPU, memory, disk and a CPU
// history line), Network (state and live speeds) and the Assistant card.
// Live figures come from System.stats() every two seconds.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: System.setting("desktop/widgets", true) !== "false"
    color: "transparent"
    title: "Enclave Widgets"
    width: 312
    height: column.height + 24

    property Status status

    LayerShell.Window.scope: "enclave-widgets"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // ---- live figures ----
    property real cpu: 0
    property real memory: 0
    property real disk: 0
    property real rxRate: 0
    property real txRate: 0
    property var cpuHistory: []
    property var rxHistory: []
    property var last: null
    property real lastTime: 0

    function push(list, v) {
        const out = list.slice(-39)
        out.push(v)
        return out
    }
    function sample() {
        const s = System.stats()
        const now = Date.now()
        root.cpu = s.cpu || 0
        root.memory = s.memory || 0
        root.disk = s.disk || 0
        if (root.last && now > root.lastTime) {
            const dt = (now - root.lastTime) / 1000
            root.rxRate = Math.max(0, (s.rx - root.last.rx) / dt)
            root.txRate = Math.max(0, (s.tx - root.last.tx) / dt)
        }
        root.last = s
        root.lastTime = now
        root.cpuHistory = push(root.cpuHistory, root.cpu)
        root.rxHistory = push(root.rxHistory, root.rxRate)
    }
    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s"
        return Math.round(bps) + " B/s"
    }
    Timer { interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }

    // A history line with a soft fill, drawn in the accent colour.
    component Spark: Canvas {
        id: spark
        property var values: []
        property real max: 1
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        Connections { target: Theme; function onChanged() { spark.requestPaint() } }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const v = values, n = v.length
            if (n < 2) return
            const top = Math.max(max, ...v) || 1
            const px = i => i * width / 39 + (39 - (n - 1)) * width / 39
            const py = x => height - 2 - (x / top) * (height - 4)
            ctx.beginPath()
            ctx.moveTo(px(0), py(v[0]))
            for (let i = 1; i < n; ++i) ctx.lineTo(px(i), py(v[i]))
            ctx.lineWidth = 1.6
            ctx.strokeStyle = Qt.color(Theme.c.accent)
            ctx.stroke()
            ctx.lineTo(px(n - 1), height)
            ctx.lineTo(px(0), height)
            ctx.closePath()
            const g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0, Qt.alpha(Theme.c.accent, 0.28))
            g.addColorStop(1, Qt.alpha(Theme.c.accent, 0))
            ctx.fillStyle = g
            ctx.fill()
        }
    }

    // A labelled usage bar.
    component Meter: Item {
        id: meter
        property string label: ""
        property real value: 0
        width: parent ? parent.width : 260
        height: 22
        Text {
            id: meterLabel
            width: 64
            anchors.verticalCenter: parent.verticalCenter
            text: meter.label
            color: Theme.c.text
            font.pointSize: 9
        }
        Rectangle {
            anchors { left: meterLabel.right; right: meterValue.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            height: 5; radius: 2.5
            color: Theme.c.pressed
            Rectangle {
                height: parent.height; radius: 2.5
                width: Math.max(height, parent.width * Math.min(1, meter.value))
                color: meter.value > 0.9 ? Theme.status.danger : Theme.c.accent
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            id: meterValue
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(meter.value * 100) + "%"
            color: Theme.c.textSecondary
            font.pointSize: 9
            font.features: { "tnum": 1 }
        }
    }

    // A widget card with a titled header.
    component Card: Item {
        id: card
        property string icon: ""
        property string title: ""
        property string action: ""
        default property alias content: cardBody.data
        signal clicked()
        width: parent ? parent.width : 288
        height: cardBody.childrenRect.height + 56
        Glass { anchors.fill: parent; radius: Theme.radius.large - 2; shadowDepth: 3 }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.large - 2
            color: cardMouse.containsMouse ? Theme.c.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        }
        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.clicked() }
        Row {
            x: 16; y: 14
            spacing: 10
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                sourceSize: Qt.size(32, 32)
                source: card.icon === "" ? "" : "image://icon/" + card.icon + "?color=" + encodeURIComponent(Theme.c.accent)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.title
                color: Theme.c.text
                font.pointSize: 10
                font.weight: Font.DemiBold
            }
        }
        Image {
            visible: cardMouse.containsMouse
            anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 15 }
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: "image://icon/go-next-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
        }
        Item {
            id: cardBody
            x: 16; y: 44
            width: card.width - 32
            height: childrenRect.height
        }
    }

    Column {
        id: column
        x: 12; y: 12
        width: root.width - 24
        spacing: 12

        Card {
            icon: "computer-symbolic"
            title: "System Overview"
            onClicked: Apps.launch("xfce4-taskmanager.desktop")
            Column {
                width: parent.width
                spacing: 2
                Meter { label: "Processor"; value: root.cpu }
                Meter { label: "Memory"; value: root.memory }
                Meter { label: "Disk"; value: root.disk }
                Item { width: 1; height: 6 }
                Spark { width: parent.width; height: 40; values: root.cpuHistory; max: 1 }
            }
        }

        Card {
            icon: root.status ? root.status.netIcon : "network-wired-symbolic"
            title: "Network"
            onClicked: System.run("nm-connection-editor")
            Item {
                width: parent.width
                height: 64
                Column {
                    spacing: 4
                    Row {
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 3.5
                            color: root.status && root.status.netType !== "none" ? Theme.status.success : Theme.c.textSecondary
                        }
                        Text {
                            text: root.status ? (root.status.netType !== "none" ? "Connected" : root.status.netLabel) : ""
                            color: root.status && root.status.netType !== "none" ? Theme.status.success : Theme.c.textSecondary
                            font.pointSize: 9
                        }
                    }
                    Text {
                        visible: !!root.status && root.status.netName !== ""
                        text: root.status ? root.status.netName : ""
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                        width: 130
                        elide: Text.ElideRight
                    }
                    Grid {
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 2
                        Text { text: "Download"; color: Theme.c.textSecondary; font.pointSize: 8.5 }
                        Text { text: root.rate(root.rxRate); color: Theme.c.text; font.pointSize: 8.5; font.features: { "tnum": 1 } }
                        Text { text: "Upload"; color: Theme.c.textSecondary; font.pointSize: 8.5 }
                        Text { text: root.rate(root.txRate); color: Theme.c.text; font.pointSize: 8.5; font.features: { "tnum": 1 } }
                    }
                }
                Spark {
                    anchors { right: parent.right; bottom: parent.bottom }
                    width: 120; height: 46
                    values: root.rxHistory
                    max: 1024
                }
            }
        }

        Card {
            visible: Apps.app("enclave-assistant.desktop").appId !== undefined
            icon: "starred-symbolic"
            title: "Enclave Assistant"
            onClicked: Apps.launch("enclave-assistant.desktop")
            Column {
                width: parent.width
                spacing: 10
                Text {
                    property int hour: new Date().getHours()
                    text: (hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening")
                          + ", " + System.userName + "."
                    color: Theme.c.text
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 17
                    color: Theme.c.hover
                    border.width: 1
                    border.color: Theme.c.border
                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "Ask anything…"
                        color: Theme.c.textSecondary
                        font.pointSize: 9
                    }
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 26; height: 26; radius: 13
                        color: Theme.c.accent
                        Image {
                            anchors.centerIn: parent
                            width: 12; height: 12
                            sourceSize: Qt.size(24, 24)
                            source: "image://icon/go-up-symbolic?color=" + encodeURIComponent(Theme.c.accentText)
                        }
                    }
                }
                Item { width: 1; height: 2 }
            }
        }
    }
}
