// About: Enclave OS, this computer's name and hardware, and a copy button for
// support.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "About"

    property var os: ({})
    property string host: ""
    property string cpu: ""
    property string gpu: ""
    property string copied: ""
    readonly property var stats: System.stats()

    function size(bytes) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (bytes >= 1024 && i < u.length - 1) { bytes /= 1024; ++i }
        return (i > 1 ? bytes.toFixed(i > 2 ? 1 : 0) : Math.round(bytes)) + " " + u[i]
    }
    readonly property var details: [
        { k: "Device name", v: host },
        { k: "Processor", v: cpu },
        { k: "Memory", v: stats.memoryTotal ? size(stats.memoryTotal) : "" },
        { k: "Graphics", v: gpu },
        { k: "Storage", v: stats.diskTotal ? size(stats.diskTotal) + " (home drive)" : "" },
        { k: "Built on", v: "Arch Linux (rolling)" },
        { k: "Kernel", v: System.readFile("/proc/sys/kernel/osrelease") },
        { k: "Desktop", v: "Enclave Shell on " + (System.compositor === "hyprland" ? "Hyprland" : System.compositor) + " (Wayland)" }
    ]

    Component.onCompleted: {
        const o = {}
        // Enclave's own copy first: a package update may rewrite /etc/os-release
        const release = System.readFile("/usr/share/enclave/os-release") || System.readFile("/etc/os-release")
        for (const l of release.split("\n")) {
            const i = l.indexOf("=")
            if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).replace(/^"|"$/g, "")
        }
        page.os = o
        page.host = System.readFile("/etc/hostname") || System.readFile("/proc/sys/kernel/hostname")
        const m = /model name\s*:\s*(.+)/.exec(System.readFile("/proc/cpuinfo"))
        const cores = (System.readFile("/proc/cpuinfo").match(/^processor\s*:/gm) || []).length
        page.cpu = m ? m[1].replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim() + (cores ? " · " + cores + " threads" : "") : ""
        System.query("sh", ["-c", "lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1 | sed 's/^[^ ]* [^:]*: //'"], (out) => {
            page.gpu = out.trim().replace(/Corporation|\[|\]/g, "").replace(/\s+/g, " ") || "Integrated"
        })
    }

    // hero
    Rectangle {
        width: parent.width
        height: 190
        radius: Theme.radius.medium + 2
        color: Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        clip: true
        // a soft ember glow rising from below the logo
        Canvas {
            id: glow
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height * 1.15, 10, width / 2, height * 1.15, width * 0.55)
                g.addColorStop(0, Qt.rgba(1, 0.478, 0.102, Theme.dark ? 0.34 : 0.24))
                g.addColorStop(0.55, Qt.rgba(1, 0.478, 0.102, Theme.dark ? 0.10 : 0.07))
                g.addColorStop(1, Qt.rgba(1, 0.478, 0.102, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            Connections { target: Theme; function onChanged() { glow.requestPaint() } }
        }
        Column {
            anchors.centerIn: parent
            spacing: 8
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72
                sourceSize: Qt.size(144, 144)
                source: "file:///usr/share/enclave/" + (Theme.dark ? "enclave-logo-dark.svg" : "enclave-logo.svg")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Enclave OS"      // always: this is Enclave, whatever the base reports
                color: Theme.c.text
                font.pointSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property bool own: page.os.ID === "enclave"
                text: [own && page.os.IMAGE_VERSION ? "Version " + page.os.IMAGE_VERSION : "",
                       own && page.os.VERSION ? page.os.VERSION : "", "Rolling release"].filter(x => x).join("  ·  ")
                color: Theme.c.textSecondary
                font.pointSize: 9.5
            }
        }
    }

    Controls.Group {
        title: "This computer"
        note: page.copied
        Repeater {
            model: page.details.filter(d => d.v)
            delegate: Controls.Field {
                required property var modelData
                height: 44
                title: modelData.k
                Text {
                    width: 420
                    horizontalAlignment: Text.AlignRight
                    text: modelData.v
                    color: Theme.c.textSecondary
                    font.pointSize: 9.5
                    elide: Text.ElideLeft
                }
            }
        }
    }

    Row {
        spacing: 8
        Controls.Button {
            text: "Copy details"
            icon: "edit-copy-symbolic"
            onClicked: {
                const text = ["Enclave OS" + (page.os.ID === "enclave" && page.os.IMAGE_VERSION ? " " + page.os.IMAGE_VERSION : "")].concat(page.details.filter(d => d.v).map(d => d.k + ": " + d.v)).join("\n")
                System.query("wl-copy", [text], (out, code) => page.copied = code === 0 ? "Copied to the clipboard." : "")
            }
        }
        Controls.Button {
            text: "Rename this computer"
            icon: "document-edit-symbolic"
            onClicked: renameRow.visible = !renameRow.visible
        }
    }
    Row {
        id: renameRow
        visible: false
        spacing: 8
        Controls.Input { id: newName; width: 240; placeholderText: page.host; onAccepted: renameBtn.clicked() }
        Controls.Button {
            id: renameBtn
            text: "Save"
            primary: true
            onClicked: {
                const n = newName.text.trim().replace(/[^A-Za-z0-9-]/g, "-")
                if (n === "") return
                System.query("hostnamectl", ["hostname", n], (out, code) => {
                    page.copied = code === 0 ? "This computer is now called " + n + "." : "Couldn't rename — it needs administrator approval."
                    if (code === 0) { page.host = n; renameRow.visible = false }
                }, 60000)
            }
        }
    }
}
