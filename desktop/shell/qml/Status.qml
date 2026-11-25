// Enclave Shell — live system status for the status widget and Control
// Center: network (NetworkManager), sound (PipeWire/wpctl), battery (sysfs)
// and Do Not Disturb (mako). Every query is asynchronous (System.query), so a
// slow or missing service never freezes the shell; it just shows as absent.
import QtQuick
import Enclave

QtObject {
    id: s

    property string netType: "none"     // wifi | ethernet | none
    property string netName: ""
    property bool wifiOn: true
    property bool hasWifi: false
    property int wifiSignal: 0
    property bool hasAudio: false
    property real volume: 0
    property bool muted: false
    property int battery: -1            // -1: no battery
    property bool charging: false
    property string batteryStatus: ""   // Charging | Discharging | Full | Not charging
    property int batteryMinutes: -1     // to empty (or to full while charging); -1 unknown
    property bool dnd: false
    property bool fast: false           // poll quicker while Control Center is open

    readonly property string netIcon: {
        if (netType === "ethernet") return "network-wired-symbolic"
        if (netType === "wifi") {
            const q = wifiSignal >= 75 ? "excellent" : wifiSignal >= 50 ? "good"
                    : wifiSignal >= 25 ? "ok" : "weak"
            return "network-wireless-signal-" + q + "-symbolic"
        }
        return hasWifi && !wifiOn ? "network-wireless-offline-symbolic" : "network-offline-symbolic"
    }
    readonly property string netLabel: netType === "none"
        ? (hasWifi && !wifiOn ? "Wi-Fi off" : "Not connected")
        : (netName || (netType === "wifi" ? "Wi-Fi" : "Ethernet"))
    readonly property string volumeIcon: !hasAudio || muted || volume <= 0.001 ? "audio-volume-muted-symbolic"
        : volume < 0.34 ? "audio-volume-low-symbolic"
        : volume < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
    readonly property string batteryIcon: battery < 0 ? ""
        : "battery-level-" + Math.round(battery / 10) * 10 + (charging ? "-charging" : "") + "-symbolic"

    function refresh() {
        System.query("nmcli", ["-t", "-f", "TYPE,STATE,CONNECTION", "device"], (out, code) => {
            let type = "none", name = "", wifi = false
            for (const line of out.split("\n")) {
                const f = line.split(":")
                if (f[0] === "wifi") wifi = true
                if (f[1] !== "connected" || (f[0] !== "wifi" && f[0] !== "ethernet")) continue
                if (type === "none" || f[0] === "ethernet") {
                    type = f[0]
                    name = f.slice(2).join(":").replace(/\\/g, "")
                }
            }
            s.netType = type; s.netName = name; s.hasWifi = wifi
            if (type === "wifi")
                System.query("nmcli", ["-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no"],
                             (o) => {
                    for (const l of o.split("\n"))
                        if (l.startsWith("*:")) s.wifiSignal = parseInt(l.slice(2)) || 0
                })
        })
        System.query("nmcli", ["radio", "wifi"], (out) => s.wifiOn = out !== "disabled")
        if (!volumeDrag)
            System.query("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"], (out, code) => {
                const m = /Volume:\s*([\d.]+)/.exec(out)
                s.hasAudio = code === 0 && !!m
                if (m) s.volume = parseFloat(m[1])
                s.muted = out.indexOf("[MUTED]") >= 0
            })
        // capacity, status, then energy (or charge) now/full and power (or current)
        System.query("sh", ["-c", "for b in /sys/class/power_supply/BAT*; do cd \"$b\" || break; "
                            + "cat capacity status; cat energy_now charge_now energy_full charge_full power_now current_now 2>/dev/null | tr '\n' ' '; break; done 2>/dev/null"],
                     (out) => {
            const l = out.split("\n")
            s.battery = l.length >= 1 && l[0] !== "" ? (parseInt(l[0]) || 0) : -1
            s.batteryStatus = l.length >= 2 ? l[1] : ""
            s.charging = s.batteryStatus === "Charging" || s.batteryStatus === "Full"
            // now, full, rate (the three present files, in that order)
            const n = (l[2] || "").trim().split(/\s+/).map(Number).filter(x => !isNaN(x))
            s.batteryMinutes = -1
            if (n.length >= 3 && n[2] > 0) {
                const hours = s.batteryStatus === "Charging" ? (n[1] - n[0]) / n[2] : n[0] / n[2]
                if (hours > 0 && hours < 48) s.batteryMinutes = Math.round(hours * 60)
            }
        })
        System.query("makoctl", ["mode"], (out) => s.dnd = out.split("\n").indexOf("do-not-disturb") >= 0)
    }

    property bool volumeDrag: false
    function setVolume(v) {
        s.volume = v
        System.query("wpctl", ["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)], () => {})
        if (s.muted && v > 0) toggleMute()
    }
    function toggleMute() {
        s.muted = !s.muted
        System.query("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], () => {})
    }
    function toggleWifi() {
        s.wifiOn = !s.wifiOn
        System.query("nmcli", ["radio", "wifi", s.wifiOn ? "on" : "off"], () => s.refresh())
    }
    function toggleDnd() {
        s.dnd = !s.dnd
        System.query("makoctl", ["mode", "-t", "do-not-disturb"], () => s.refresh())
    }

    property Timer poll: Timer {
        interval: s.fast ? 2000 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: s.refresh()
    }
}
