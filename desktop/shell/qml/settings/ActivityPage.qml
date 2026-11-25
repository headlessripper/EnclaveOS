// Activity — Enclave's task manager: live processor, memory, disk and network
// graphs, then every process (heaviest first) with a filter. Select one to
// end it (or force-quit it). Ctrl+Shift+Esc opens here.
import QtQuick
import QtQuick.Controls as T
import Enclave

Controls.Page {
    id: page
    title: "Activity"
    lead: "What's running, and how hard the computer is working."

    property var cpu: []
    property var mem: []
    property real disk: 0
    property real memTotal: 0
    property real rx: 0
    property real tx: 0
    property real lastRx: -1
    property real lastTx: -1
    property var procs: []          // [{ pid, user, cpu, rss, name }]
    property int selectedPid: -1
    property string sortBy: "cpu"
    property string message: ""

    function push(list, v) { const l = list.slice(-59); l.push(v); return l }
    function size(bytes) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (bytes >= 1024 && i < u.length - 1) { bytes /= 1024; ++i }
        return (i > 1 ? bytes.toFixed(1) : Math.round(bytes)) + " " + u[i]
    }
    function sample() {
        const s = System.stats()
        page.cpu = push(page.cpu, s.cpu || 0)
        page.mem = push(page.mem, s.memory || 0)
        page.disk = s.disk || 0
        page.memTotal = s.memoryTotal || 0
        if (page.lastRx >= 0) { page.rx = Math.max(0, (s.rx - page.lastRx) / 1.5); page.tx = Math.max(0, (s.tx - page.lastTx) / 1.5) }
        page.lastRx = s.rx; page.lastTx = s.tx
    }
    function refreshProcs() {
        System.query("ps", ["-eo", "pid=,user=,pcpu=,rss=,comm=", "--sort=" + (page.sortBy === "cpu" ? "-pcpu" : page.sortBy === "mem" ? "-rss" : "comm")], (out) => {
            page.procs = out.split("\n").map(l => {
                const f = l.trim().split(/\s+/)
                return f.length >= 5 ? { pid: Number(f[0]), user: f[1], cpu: Number(f[2]), rss: Number(f[3]) * 1024, name: f.slice(4).join(" ") } : null
            }).filter(p => p && p.name !== "ps" && p.name.indexOf("<defunct>") < 0)
        })
    }
    function end(sig) {
        const p = page.procs.find(x => x.pid === page.selectedPid)
        if (!p) return
        System.query("kill", [sig, String(p.pid)], (out, code) => {
            page.message = code === 0 ? (sig === "-KILL" ? "Force-quit " : "Ended ") + p.name + "." : "Couldn't end " + p.name + " (it may belong to the system)."
            page.selectedPid = -1
            page.refreshProcs()
        })
    }

    Component.onCompleted: { sample(); refreshProcs() }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: page.sample() }
    Timer { interval: 2500; running: true; repeat: true; onTriggered: page.refreshProcs() }

    // a live figure with a sparkline
    component Gauge: Rectangle {
        id: g
        property string label: ""
        property string value: ""
        property string detail: ""
        property var series: []
        width: 180; height: 112
        radius: Theme.radius.medium + 2
        color: Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        Column {
            x: 14; y: 12
            spacing: 1
            Text { text: g.label; color: Theme.c.textSecondary; font.pointSize: 8.5 }
            Text { text: g.value; color: Theme.c.text; font.pointSize: 15; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
            Text { text: g.detail; color: Theme.c.textSecondary; font.pointSize: 8; font.features: { "tnum": 1 } }
        }
        Canvas {
            id: spark
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 34
            Connections { target: g; function onSeriesChanged() { spark.requestPaint() } }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const n = g.series.length
                if (n < 2) return
                const step = width / 59
                ctx.beginPath()
                ctx.moveTo(width - (n - 1) * step, height)
                for (let i = 0; i < n; ++i)
                    ctx.lineTo(width - (n - 1 - i) * step, height - 2 - g.series[i] * (height - 6))
                ctx.lineTo(width, height)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(1, 0.478, 0.102, 0.16)
                ctx.fill()
                ctx.beginPath()
                for (let i = 0; i < n; ++i) {
                    const x = width - (n - 1 - i) * step, y = height - 2 - g.series[i] * (height - 6)
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                }
                ctx.lineWidth = 1.6
                ctx.strokeStyle = Qt.color(Theme.c.accent)
                ctx.stroke()
            }
        }
    }

    Row {
        spacing: 12
        readonly property real w: (parent.width - 36) / 4
        Gauge {
            width: parent.w
            label: "Processor"
            value: Math.round((page.cpu[page.cpu.length - 1] || 0) * 100) + "%"
            detail: page.procs.length + " processes"
            series: page.cpu
        }
        Gauge {
            width: parent.w
            label: "Memory"
            value: Math.round((page.mem[page.mem.length - 1] || 0) * 100) + "%"
            detail: page.size((page.mem[page.mem.length - 1] || 0) * page.memTotal) + " of " + page.size(page.memTotal)
            series: page.mem
        }
        Gauge {
            width: parent.w
            label: "Disk"
            value: Math.round(page.disk * 100) + "%"
            detail: "used on your home drive"
            series: []
            Controls.Meter { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 } value: page.disk }
        }
        Gauge {
            width: parent.w
            label: "Network"
            value: "↓ " + page.size(page.rx) + "/s"
            detail: "↑ " + page.size(page.tx) + "/s"
            series: []
        }
    }

    Controls.Group {
        title: "Processes"
        note: page.message
        // toolbar
        Item {
            width: parent.width
            height: 54
            Controls.Input {
                id: filter
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                placeholderText: "Filter by name"
            }
            Row {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 8
                Controls.Segmented {
                    options: [{ label: "CPU", value: "cpu" }, { label: "Memory", value: "mem" }, { label: "Name", value: "name" }]
                    value: page.sortBy
                    onPicked: (v) => { page.sortBy = v; page.refreshProcs() }
                }
                Controls.Button { text: "End"; enabled: page.selectedPid > 0; onClicked: page.end("-TERM") }
                Controls.Button { text: "Force quit"; danger: true; enabled: page.selectedPid > 0; onClicked: page.end("-KILL") }
            }
        }
        // header
        Rectangle {
            width: parent.width; height: 30
            color: Theme.c.hover
            Row {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [{ t: "Name", w: 0.46 }, { t: "PID", w: 0.12 }, { t: "User", w: 0.16 }, { t: "CPU", w: 0.11 }, { t: "Memory", w: 0.15 }]
                    Text {
                        required property var modelData
                        width: (parent.parent.width - 32) * modelData.w
                        text: modelData.t
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
        ListView {
            id: list
            width: parent.width
            height: 420
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            T.ScrollBar.vertical: T.ScrollBar {}
            model: {
                const q = filter.text.trim().toLowerCase()
                return q === "" ? page.procs : page.procs.filter(p => p.name.toLowerCase().indexOf(q) >= 0)
            }
            delegate: Rectangle {
                id: procRow
                required property var modelData
                required property int index
                readonly property bool on: modelData.pid === page.selectedPid
                width: list.width
                height: 34
                color: on ? Theme.c.accentSoft : procMouse.containsMouse ? Theme.c.hover : (index % 2 ? "transparent" : Qt.rgba(0, 0, 0, Theme.dark ? 0.08 : 0.015))
                readonly property real cw: width - 32
                Row {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: procRow.cw * 0.46; text: procRow.modelData.name; color: Theme.c.text; font.pointSize: 9.5; elide: Text.ElideRight
                           font.weight: procRow.on ? Font.DemiBold : Font.Normal }
                    Text { width: procRow.cw * 0.12; text: procRow.modelData.pid; color: Theme.c.textSecondary; font.pointSize: 9; font.features: { "tnum": 1 } }
                    Text { width: procRow.cw * 0.16; text: procRow.modelData.user; color: Theme.c.textSecondary; font.pointSize: 9; elide: Text.ElideRight }
                    Text { width: procRow.cw * 0.11; text: procRow.modelData.cpu.toFixed(1) + "%"; font.pointSize: 9; font.features: { "tnum": 1 }
                           color: procRow.modelData.cpu > 50 ? Theme.c.accent : Theme.c.text }
                    Text { width: procRow.cw * 0.15; text: page.size(procRow.modelData.rss); color: Theme.c.text; font.pointSize: 9; font.features: { "tnum": 1 } }
                }
                MouseArea {
                    id: procMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: page.selectedPid = procRow.on ? -1 : procRow.modelData.pid
                    onDoubleClicked: { page.selectedPid = procRow.modelData.pid; page.end("-TERM") }
                }
            }
        }
    }
}
