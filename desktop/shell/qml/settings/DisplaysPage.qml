// Displays: each screen drawn to scale, with its resolution, refresh rate and
// scale. Reads and applies through wlr-randr (labwc) or hyprctl (Hyprland).
// Choices are kept in shell.conf ("displays/<output>") and re-applied by the
// shell when the session starts.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Displays"
    lead: "Resolution, refresh rate and size of everything on screen."

    readonly property bool hypr: System.compositor === "hyprland"
    property var outputs: []          // [{ name, description, width, height, refresh, scale, modes: [{ w, h, r }] }]
    property int selected: 0
    property string message: ""
    readonly property var current: outputs.length ? outputs[Math.min(selected, outputs.length - 1)] : null

    function refresh() {
        if (hypr) {
            System.query("hyprctl", ["monitors", "-j"], (out) => {
                try {
                    page.outputs = JSON.parse(out).map(m => ({
                        name: m.name, description: (m.make + " " + m.model).trim() || m.description,
                        width: m.width, height: m.height, refresh: m.refreshRate, scale: m.scale,
                        modes: (m.availableModes || []).map(s => {
                            const r = /(\d+)x(\d+)@([0-9.]+)/.exec(s)
                            return r ? { w: +r[1], h: +r[2], r: +r[3] } : null
                        }).filter(x => x)
                    }))
                } catch (e) { page.outputs = [] }
            })
        } else {
            System.query("wlr-randr", ["--json"], (out, code) => {
                if (code !== 0) { page.outputs = []; page.message = "wlr-randr isn't available."; return }
                try {
                    page.outputs = JSON.parse(out).filter(o => o.enabled).map(o => {
                        const cur = o.modes.find(m => m.current) || o.modes[0] || { width: 0, height: 0, refresh: 0 }
                        return {
                            name: o.name, description: [o.make, o.model].filter(x => x && x !== "Unknown").join(" ") || o.description,
                            width: cur.width, height: cur.height, refresh: cur.refresh, scale: o.scale,
                            modes: o.modes.map(m => ({ w: m.width, h: m.height, r: m.refresh }))
                        }
                    })
                } catch (e) { page.outputs = [] }
            })
        }
    }
    function apply(o, w, h, r, scale) {
        const mode = w + "x" + h + "@" + Number(r).toFixed(3)
        page.message = "Applying…"
        const done = (out, code) => {
            page.message = code === 0 ? "" : (out || "That mode didn't take.")
            if (code === 0) System.setSetting("displays/" + o.name, mode + " " + scale)
            page.refresh()
        }
        if (hypr)
            System.query("hyprctl", ["eval", "hl.monitor({ output = \"" + o.name + "\", mode = \"" + w + "x" + h + "@" + Number(r).toFixed(2)
                                              + "\", position = \"auto\", scale = " + scale + " })"], done)
        else
            System.query("wlr-randr", ["--output", o.name, "--mode", w + "x" + h + "@" + Number(r).toFixed(3) + "Hz", "--scale", String(scale)], done)
    }
    // the resolutions this screen offers (best refresh first), and the rates for one
    function resolutions(o) {
        const seen = {}, out = []
        for (const m of o.modes) {
            const k = m.w + "x" + m.h
            if (!seen[k]) { seen[k] = true; out.push({ label: m.w + " × " + m.h, value: k, w: m.w, h: m.h }) }
        }
        return out.sort((a, b) => b.w * b.h - a.w * a.h)
    }
    function rates(o) {
        const out = [], seen = {}
        for (const m of o.modes)
            if (m.w === o.width && m.h === o.height) {
                const k = Math.round(m.r)
                if (!seen[k]) { seen[k] = true; out.push({ label: k + " Hz", value: k, r: m.r }) }
            }
        return out.sort((a, b) => b.value - a.value)
    }

    Component.onCompleted: refresh()

    // the screens, drawn to scale
    Rectangle {
        width: parent.width
        height: 210
        radius: Theme.radius.medium + 2
        color: Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
        Row {
            anchors.centerIn: parent
            spacing: 24
            Repeater {
                model: page.outputs
                delegate: Item {
                    id: screen
                    required property var modelData
                    required property int index
                    readonly property real k: 150 / Math.max(1, Math.max(modelData.width, modelData.height * 1.6))
                    readonly property bool on: index === page.selected
                    width: Math.max(140, modelData.width * k * 1.4)
                    height: 170
                    Rectangle {
                        id: bezel
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        width: Math.max(140, screen.modelData.width * screen.k * 1.4)
                        height: width * screen.modelData.height / Math.max(1, screen.modelData.width)
                        radius: 8
                        color: Theme.dark ? "#0B0C0E" : "#2A2C31"
                        border.width: 2
                        border.color: screen.on ? Theme.c.accent : Theme.c.border
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 4
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#1B1D23" }
                                GradientStop { position: 0.7; color: "#3A2418" }
                                GradientStop { position: 1; color: Theme.brand.burnt }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: screen.modelData.name
                                color: "white"
                                font.pointSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.selected = screen.index }
                    }
                    Rectangle {   // the stand
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: bezel.bottom
                        width: 36; height: 10
                        color: Theme.c.elevated
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: screen.modelData.width + " × " + screen.modelData.height
                        color: Theme.c.textSecondary
                        font.pointSize: 8.5
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: page.outputs.length === 0
            text: page.message !== "" ? page.message : "Looking for displays…"
            color: Theme.c.textSecondary
            font.pointSize: 9.5
        }
    }

    Controls.Group {
        visible: !!page.current
        title: page.current ? page.current.name + (page.current.description ? " · " + page.current.description : "") : ""
        note: page.message
        Controls.Field {
            icon: "video-display-symbolic"
            title: "Resolution"
            subtitle: page.current ? page.current.width + " × " + page.current.height : ""
            Controls.Choice {
                options: page.current ? page.resolutions(page.current) : []
                value: page.current ? page.current.width + "x" + page.current.height : ""
                onPicked: (v) => {
                    const o = page.current, wh = v.split("x").map(Number)
                    const best = o.modes.filter(m => m.w === wh[0] && m.h === wh[1]).sort((a, b) => b.r - a.r)[0]
                    if (best) page.apply(o, best.w, best.h, best.r, o.scale)
                }
            }
        }
        Controls.Field {
            icon: "preferences-desktop-display-symbolic"
            title: "Refresh rate"
            Controls.Choice {
                options: page.current ? page.rates(page.current) : []
                value: page.current ? Math.round(page.current.refresh) : 0
                onPicked: (v) => {
                    const o = page.current, m = page.rates(o).find(x => x.value === v)
                    if (m) page.apply(o, o.width, o.height, m.r, o.scale)
                }
            }
        }
        Controls.Field {
            icon: "zoom-in-symbolic"
            title: "Scale"
            subtitle: "Makes text, icons and windows larger"
            Controls.Segmented {
                options: [{ label: "100%", value: 1 }, { label: "125%", value: 1.25 },
                          { label: "150%", value: 1.5 }, { label: "200%", value: 2 }]
                value: page.current ? page.current.scale : 1
                onPicked: (v) => page.apply(page.current, page.current.width, page.current.height, page.current.refresh, v)
            }
        }
    }
}
