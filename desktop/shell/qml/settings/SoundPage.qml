// Sound: output and input volume, mute, and which device plays / listens.
// PipeWire via wpctl (volume) and pactl (device list, default device).
import QtQuick
import Enclave
import "../components"

Controls.Page {
    id: page
    title: "Sound"
    lead: "Speakers, headphones and microphones."

    property real outVolume: 0
    property bool outMuted: false
    property real inVolume: 0
    property bool inMuted: false
    property var sinks: []            // [{ name, label }]
    property var sources: []
    property string defaultSink: ""
    property string defaultSource: ""

    function parseVolume(out) {
        const m = /Volume:\s*([0-9.]+)/.exec(out)
        return { volume: m ? Number(m[1]) : 0, muted: out.indexOf("MUTED") >= 0, ok: !!m }
    }
    function refresh() {
        System.query("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"], (out) => {
            const v = parseVolume(out)
            if (!outSlider.pressed) page.outVolume = v.volume
            page.outMuted = v.muted
        })
        System.query("wpctl", ["get-volume", "@DEFAULT_AUDIO_SOURCE@"], (out) => {
            const v = parseVolume(out)
            if (!inSlider.pressed) page.inVolume = v.volume
            page.inMuted = v.muted
        })
        // "index  name  driver  format  state" — one device per line
        const list = (kind, done) => System.query("sh", ["-c",
            "pactl list " + kind + " | awk -F': ' '/^\\s*Name:/{n=$2} /^\\s*Description:/{print n \"\\t\" $2}'"], (out) => {
                done(out.split("\n").filter(l => l.indexOf("\t") > 0)
                        .map(l => { const f = l.split("\t"); return { value: f[0], label: f[1] } })
                        .filter(d => d.value.indexOf(".monitor") < 0))
            })
        list("sinks", (d) => page.sinks = d)
        list("sources", (d) => page.sources = d)
        System.query("pactl", ["get-default-sink"], (out) => page.defaultSink = out)
        System.query("pactl", ["get-default-source"], (out) => page.defaultSource = out)
    }
    function setVolume(target, v) {
        System.query("wpctl", ["set-volume", "-l", "1.0", target, v.toFixed(2)], () => {})
    }

    Component.onCompleted: refresh()
    Timer { interval: 3000; running: true; repeat: true; onTriggered: page.refresh() }

    Controls.Group {
        title: "Output"
        Controls.Field {
            icon: page.outMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
            iconLive: !page.outMuted && page.outVolume > 0
            title: "Output volume"
            subtitle: page.outMuted ? "Muted" : Math.round(page.outVolume * 100) + "%"
            Row {
                spacing: 12
                EmberSlider {
                    id: outSlider
                    width: 240
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "audio-volume-high-symbolic"
                    value: page.outVolume
                    onMoved: { page.outVolume = value; page.setVolume("@DEFAULT_AUDIO_SINK@", value) }
                }
                Controls.Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !page.outMuted
                    onToggled: (on) => System.query("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", on ? "0" : "1"], () => page.refresh())
                }
            }
        }
        Controls.Field {
            icon: "audio-speakers-symbolic"
            title: "Play sound through"
            subtitle: page.sinks.length === 0 ? "No output devices found" : ""
            Controls.Choice {
                visible: page.sinks.length > 0
                options: page.sinks
                value: page.defaultSink
                onPicked: (v) => System.query("pactl", ["set-default-sink", v], () => page.refresh())
            }
        }
    }

    Controls.Group {
        title: "Input"
        Controls.Field {
            icon: page.inMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
            iconLive: !page.inMuted && page.inVolume > 0
            title: "Input volume"
            subtitle: page.inMuted ? "Muted" : Math.round(page.inVolume * 100) + "%"
            Row {
                spacing: 12
                EmberSlider {
                    id: inSlider
                    width: 240
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "audio-input-microphone-symbolic"
                    value: page.inVolume
                    onMoved: { page.inVolume = value; page.setVolume("@DEFAULT_AUDIO_SOURCE@", value) }
                }
                Controls.Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !page.inMuted
                    onToggled: (on) => System.query("wpctl", ["set-mute", "@DEFAULT_AUDIO_SOURCE@", on ? "0" : "1"], () => page.refresh())
                }
            }
        }
        Controls.Field {
            icon: "audio-input-microphone-symbolic"
            title: "Listen through"
            subtitle: page.sources.length === 0 ? "No microphones found" : ""
            Controls.Choice {
                visible: page.sources.length > 0
                options: page.sources
                value: page.defaultSource
                onPicked: (v) => System.query("pactl", ["set-default-source", v], () => page.refresh())
            }
        }
    }

    Controls.Group {
        Controls.Field {
            visible: Apps.app("pavucontrol.desktop").appId !== undefined
            icon: "preferences-system-symbolic"
            title: "Per-app volume and advanced audio"
            subtitle: "Mix each app, profiles, ports"
            link: true
            onClicked: System.run("pavucontrol")
        }
    }
}
