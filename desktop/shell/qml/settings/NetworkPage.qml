// Network: what you're connected to, Wi-Fi on/off, the networks in range
// (click to join; a password field opens for secured ones), airplane mode.
// NetworkManager via nmcli.
import QtQuick
import Enclave

Controls.Page {
    id: page
    title: "Network"
    lead: "Wi-Fi, Ethernet and how this computer reaches the internet."

    property var devices: []           // [{ device, type, state, connection }]
    property string address: ""
    property bool wifiOn: true
    property bool airplane: false
    property var networks: []          // [{ inUse, signal, security, ssid }]
    property bool scanning: false
    property string joining: ""        // ssid waiting for a password
    property string message: ""
    readonly property var primary: devices.find(d => d.state === "connected" && (d.type === "wifi" || d.type === "ethernet")) || null

    function refresh() {
        System.query("nmcli", ["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], (out) => {
            page.devices = out.split("\n").filter(l => l).map(l => {
                const f = l.split(":")
                return { device: f[0], type: f[1], state: f[2], connection: f.slice(3).join(":") }
            }).filter(d => d.type === "wifi" || d.type === "ethernet")
            if (page.primary)
                System.query("sh", ["-c", "ip -4 -o addr show dev \"$1\" | awk '{print $4}' | cut -d/ -f1 | head -n1", "sh", page.primary.device],
                             (ip) => page.address = ip)
            else page.address = ""
        })
        System.query("nmcli", ["radio", "wifi"], (out) => page.wifiOn = out !== "disabled")
        System.query("nmcli", ["-t", "radio", "all"], (out) => {
            const f = out.split(":")          // WIFI-HW:WIFI:WWAN-HW:WWAN
            page.airplane = f.length >= 4 && f[1] === "disabled" && f[3] === "disabled"
        })
    }
    function scan(rescan) {
        page.scanning = true
        // SSID last: it is the only field that may contain the separator
        System.query("nmcli", ["-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list", "--rescan", rescan ? "yes" : "auto"], (out) => {
            const seen = {}
            const list = []
            for (const l of out.split("\n")) {
                const p = l.split(":")
                if (p.length < 4) continue
                const ssid = p.slice(3).join(":").replace(/\\:/g, ":")
                if (ssid === "" || seen[ssid]) continue
                seen[ssid] = true
                list.push({ inUse: p[0] === "*", signal: Number(p[1]) || 0, security: p[2] === "--" ? "" : p[2], ssid: ssid })
            }
            list.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
            page.networks = list
            page.scanning = false
        }, 15000)
    }
    function join(ssid, password) {
        page.message = "Joining " + ssid + "…"
        const args = ["device", "wifi", "connect", ssid]
        if (password) args.push("password", password)
        System.query("nmcli", args, (out, code) => {
            page.message = code === 0 ? "Connected to " + ssid + "." : (out || "Couldn't join " + ssid + ".")
            page.joining = ""
            page.refresh(); page.scan(false)
        }, 45000)
    }

    Component.onCompleted: { refresh(); scan(false) }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.refresh() }

    // ---- status ----
    Controls.Group {
        Controls.Field {
            height: 84
            icon: !page.primary ? "network-offline-symbolic"
                : page.primary.type === "wifi" ? "network-wireless-symbolic" : "network-wired-symbolic"
            iconLive: !!page.primary
            title: page.primary ? page.primary.connection : "Not connected"
            subtitle: page.primary ? (page.primary.type === "wifi" ? "Wi-Fi" : "Ethernet") + " · connected"
                                     + (page.address ? " · " + page.address : "")
                                   : page.airplane ? "Airplane mode is on" : "Choose a network below, or plug in a cable"
            Controls.Button {
                visible: !!page.primary
                text: "Disconnect"
                onClicked: System.query("nmcli", ["device", "disconnect", page.primary.device], () => page.refresh())
            }
        }
    }

    // ---- Wi-Fi ----
    Controls.Group {
        title: "Wi-Fi"
        Controls.Field {
            icon: "network-wireless-symbolic"
            title: "Wi-Fi"
            subtitle: page.wifiOn ? (page.networks.length + " networks nearby") : "Off"
            Controls.Switch {
                checked: page.wifiOn
                onToggled: (on) => System.query("nmcli", ["radio", "wifi", on ? "on" : "off"], () => { page.refresh(); if (on) page.scan(true) })
            }
        }
        Repeater {
            model: page.wifiOn ? page.networks.slice(0, 14) : []
            delegate: Controls.Field {
                id: net
                required property var modelData
                readonly property bool asking: page.joining === modelData.ssid
                title: modelData.ssid
                subtitle: modelData.inUse ? "Connected" : modelData.security !== "" ? "Secured · " + modelData.security : "Open network"
                clickable: !modelData.inUse
                height: asking ? 100 : 52
                onClicked: {
                    if (modelData.security === "") page.join(modelData.ssid, "")
                    else { page.joining = modelData.ssid; pw.text = ""; pw.forceActiveFocus() }
                }
                Row {
                    spacing: 10
                    Image {
                        visible: net.modelData.security !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 13
                        sourceSize: Qt.size(26, 26)
                        source: "image://icon/changes-prevent-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
                    }
                    // signal bars
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        height: 16
                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 3; radius: 1.5
                                height: 4 + index * 4
                                color: index < Math.max(1, Math.ceil(net.modelData.signal / 25))
                                       ? (net.modelData.inUse ? Theme.c.accent : Theme.c.text) : Theme.c.border
                            }
                        }
                    }
                }
                // password, inline
                Row {
                    visible: net.asking
                    x: 16
                    y: 54
                    spacing: 8
                    Controls.Input {
                        id: pw
                        width: 260
                        echoMode: TextInput.Password
                        placeholderText: "Password for " + net.modelData.ssid
                        onAccepted: page.join(net.modelData.ssid, text)
                    }
                    Controls.Button { text: "Join"; primary: true; onClicked: page.join(net.modelData.ssid, pw.text) }
                    Controls.Button { text: "Cancel"; onClicked: page.joining = "" }
                }
            }
        }
        Controls.Field {
            visible: page.wifiOn
            title: page.scanning ? "Looking for networks…" : "Other networks"
            subtitle: page.message
            Controls.Button {
                text: "Scan again"
                icon: "view-refresh-symbolic"
                enabled: !page.scanning
                onClicked: page.scan(true)
            }
        }
    }

    // ---- more ----
    Controls.Group {
        title: "More"
        Controls.Field {
            icon: "airplane-mode-symbolic"
            iconLive: page.airplane
            title: "Airplane mode"
            subtitle: "Turns off Wi-Fi and every other radio"
            Controls.Switch {
                checked: page.airplane
                onToggled: (on) => System.query("nmcli", ["radio", "all", on ? "off" : "on"], () => page.refresh())
            }
        }
        Controls.Field {
            visible: Apps.app("nm-connection-editor.desktop").appId !== undefined
            icon: "preferences-system-network-symbolic"
            title: "VPN and advanced connections"
            subtitle: "Proxies, VPNs, static addresses"
            link: true
            onClicked: System.run("nm-connection-editor")
        }
    }
}
