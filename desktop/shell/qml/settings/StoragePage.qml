// Storage: every mounted drive with how full it is, the Trash, and a way into
// Files.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Storage"
    lead: "How much space is used, and where."

    property var drives: []         // [{ source, type, size, used, avail, mount }]
    property string trashSize: ""

    function size(bytes) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (bytes >= 1000 && i < u.length - 1) { bytes /= 1000; ++i }
        return (i > 1 ? bytes.toFixed(1) : Math.round(bytes)) + " " + u[i]
    }
    function refresh() {
        System.query("df", ["-B1", "--output=source,fstype,size,used,avail,target",
                            "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "squashfs"], (out) => {
            const seen = {}
            page.drives = out.split("\n").slice(1).map(l => l.trim().split(/\s+/)).filter(f => f.length >= 6).map(f => ({
                source: f[0], type: f[1], size: Number(f[2]), used: Number(f[3]), avail: Number(f[4]), mount: f.slice(5).join(" ")
            })).filter(d => d.size > 0 && !seen[d.source] && (seen[d.source] = true))
              .filter(d => d.mount === "/" || d.mount.startsWith("/home") || d.mount.startsWith("/boot")
                           || d.mount.startsWith("/run/media") || d.mount.startsWith("/mnt") || d.mount.startsWith("/media"))
        })
        System.query("sh", ["-c", "du -sb \"${XDG_DATA_HOME:-$HOME/.local/share}/Trash\" 2>/dev/null | cut -f1"],
                     (out) => page.trashSize = out === "" ? "" : page.size(Number(out)))
    }
    Component.onCompleted: refresh()

    Repeater {
        model: page.drives
        delegate: Controls.Group {
            required property var modelData
            title: modelData.mount === "/" ? "System drive" : modelData.mount.startsWith("/home") ? "Home"
                 : modelData.mount.startsWith("/boot") ? "Boot" : modelData.mount.split("/").pop()
            Item {
                width: parent.width
                height: 96
                Controls.Tile {
                    x: 16; y: 18
                    size: 40
                    icon: modelData.mount.startsWith("/run/media") || modelData.mount.startsWith("/media") ? "drive-removable-media-symbolic" : "drive-harddisk-symbolic"
                    live: modelData.used / modelData.size > 0.9
                }
                Column {
                    x: 72; y: 18
                    width: parent.width - 88
                    spacing: 8
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width / 2
                            text: page.size(modelData.avail) + " free"
                            color: Theme.c.text
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: page.size(modelData.used) + " of " + page.size(modelData.size) + " used"
                            color: Theme.c.textSecondary
                            font.pointSize: 9
                        }
                    }
                    Controls.Meter { width: parent.width; height: 10; radius: 5; value: modelData.used / modelData.size }
                    Text {
                        text: modelData.source + " · " + modelData.type + " · " + modelData.mount
                        color: Theme.c.textSecondary
                        font.pointSize: 8
                    }
                }
            }
        }
    }

    Controls.Group {
        title: "Free up space"
        Controls.Field {
            icon: "user-trash-symbolic"
            title: "Trash"
            subtitle: page.trashSize === "" || page.trashSize === "0 B" ? "Empty" : page.trashSize + " in the Trash"
            Row {
                spacing: 8
                Controls.Button { text: "Open"; onClicked: System.run("thunar", ["trash:///"]) }
                Controls.Button {
                    text: "Empty Trash"
                    danger: true
                    enabled: page.trashSize !== "" && page.trashSize !== "0 B"
                    onClicked: System.query("gio", ["trash", "--empty"], () => page.refresh(), 30000)
                }
            }
        }
        Controls.Field {
            icon: "system-file-manager-symbolic"
            title: "Browse your files"
            link: true
            onClicked: System.run("thunar", [System.homePath])
        }
    }
}
