// Enclave Shell — Search (Super+Space, or the desktop search widget): one
// field that finds apps, settings, files in your home folder, answers
// arithmetic, and hands anything else to the web. Results are grouped; the
// first one is the top hit and Enter opens it.
import QtQuick
import QtQuick.Controls
import Enclave
import "components"

Flyout {
    id: root
    scope: "enclave-search"
    align: "centre"
    panelWidth: 680
    padding: 10
    topOffset: Math.round(height * 0.2)

    readonly property string query: field.text.trim()
    property var appHits: []
    property var fileHits: []
    property int selected: 0

    onAboutToOpen: { field.text = ""; fileHits = []; appHits = []; selected = 0; field.forceActiveFocus() }
    onShownChanged: if (shown) field.forceActiveFocus()

    // ---- the sources ----
    onQueryChanged: {
        appHits = query === "" ? [] : Apps.search(query, 8)
        fileHits = []
        selected = 0
        fileTimer.restart()
    }
    Timer {
        id: fileTimer
        interval: 180
        onTriggered: {
            if (root.query.length < 2) return
            const q = root.query
            // $1 is the query: passed as an argument, never spliced into the script.
            System.query("sh", ["-c",
                'find "$HOME" -maxdepth 5 \\( -path "*/.*" -prune \\) -o -iname "*$1*" -printf "%y %p\\n" 2>/dev/null | head -n 24',
                "sh", q], (out) => {
                    if (q !== root.query) return
                    root.fileHits = out.split("\n").filter(l => l.length > 2)
                                       .map(l => ({ dir: l[0] === "d", path: l.slice(2) }))
                })
        }
    }

    function fileIcon(f) {
        if (f.dir) return "folder"
        const ext = f.path.split(".").pop().toLowerCase()
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "heic"].includes(ext)) return "image-x-generic"
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext)) return "video-x-generic"
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext)) return "audio-x-generic"
        if (ext === "pdf") return "application-pdf"
        if (["zip", "tar", "gz", "xz", "7z", "rar", "zst"].includes(ext)) return "package-x-generic"
        return "text-x-generic"
    }
    function pretty(path) {
        return path.startsWith(System.homePath) ? "~" + path.slice(System.homePath.length) : path
    }
    function calc(q) {
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q)) return null
        try {
            const r = Function("return (" + q.replace(/\^/g, "**").replace(/,/g, ".") + ")")()
            return (typeof r === "number" && isFinite(r)) ? String(Number(r.toPrecision(12))) : null
        } catch (e) { return null }
    }

    // Everything, in display order, as one list the keyboard walks through.
    readonly property var entries: {
        const out = []
        if (query === "") {
            for (const f of System.recentFiles(6))
                out.push({ section: "Recent", title: f.title, subtitle: f.subtitle,
                           icon: f.icon || "text-x-generic", run: () => System.openUrl(f.url) })
            return out
        }
        const answer = calc(query)
        if (answer !== null)
            out.push({ section: "Calculator", title: "= " + answer, subtitle: "Enter to copy",
                       icon: "accessories-calculator-symbolic", tint: true,
                       run: () => System.run("sh", ["-c", 'printf %s "$1" | wl-copy', "sh", answer]) })
        for (const a of appHits) {
            const info = Apps.app(a.appId)
            out.push({ section: info.settings ? "Settings" : "Apps", title: a.name, subtitle: a.comment || "",
                       icon: a.icon, run: () => Apps.launch(a.appId) })
        }
        for (const f of fileHits.slice(0, 8))
            out.push({ section: f.dir ? "Folders" : "Files", title: f.path.split("/").pop(),
                       subtitle: root.pretty(f.path.slice(0, f.path.lastIndexOf("/"))),
                       icon: root.fileIcon(f), run: () => System.openUrl("file://" + f.path) })
        out.push({ section: "Web", title: "Search the web for “" + query + "”", subtitle: "Opens your browser",
                   icon: "web-browser-symbolic", tint: true,
                   run: () => System.openUrl("https://duckduckgo.com/?q=" + encodeURIComponent(query)) })
        return out
    }
    function activate(i) {
        const e = entries[i]
        if (!e) return
        e.run()
        root.close()
    }

    Column {
        width: parent.width
        spacing: 8

        SearchField {
            id: field
            width: parent.width
            implicitHeight: 52
            font.pointSize: 14
            leftPadding: 46
            placeholderText: "Search apps, settings, files and the web"
            Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.entries.length - 1)
            Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
            Keys.onReturnPressed: root.activate(root.selected)
            Keys.onEnterPressed: root.activate(root.selected)
            Keys.onEscapePressed: root.close()
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 440)
            visible: count > 0
            clip: true
            model: root.entries
            currentIndex: root.selected
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.motion.fast
            section.property: "section"
            section.delegate: Text {
                required property string section
                width: list.width
                height: 28
                leftPadding: 12
                verticalAlignment: Text.AlignBottom
                bottomPadding: 6
                text: section
                color: Theme.c.textSecondary
                font.pointSize: 8.5
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6
            }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 48
                readonly property bool current: index === root.selected
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radius.medium - 2
                    color: row.current ? Qt.alpha(Theme.c.accent, Theme.dark ? 0.22 : 0.14)
                         : rowMouse.containsMouse ? Theme.c.hover : "transparent"
                    Rectangle {
                        visible: row.current
                        width: 3; height: 18; radius: 1.5
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        color: Theme.c.accent
                    }
                }
                Image {
                    id: rowIcon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.modelData.tint ? 20 : 30
                    height: width
                    sourceSize: Qt.size(60, 60)
                    source: "image://icon/" + row.modelData.icon
                            + (row.modelData.tint ? "?color=" + encodeURIComponent(Theme.c.accent) : "")
                }
                Column {
                    anchors { left: parent.left; leftMargin: 58; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        color: Theme.c.text
                        font.pointSize: 10.5
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.subtitle
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                        elide: Text.ElideMiddle
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = row.index
                    onClicked: root.activate(row.index)
                }
            }
        }

        Text {
            visible: root.entries.length === 0
            width: parent.width
            height: 40
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Type to search apps, settings, files — or a sum like 12*7"
            color: Theme.c.textSecondary
            font.pointSize: 9.5
        }
    }
}
