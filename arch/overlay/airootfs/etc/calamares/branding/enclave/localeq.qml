/* Enclave OS — the installer's Location page (Calamares localeq, loaded
 * from the branding folder instead of the stock OpenStreetMap page, which
 * needs the internet and looks nothing like Enclave).
 *
 * A dark card with a dot-matrix world; every time zone's city is a faint
 * ember point, the one you are in glows with a pulsing pin, a label and a
 * soft band down its longitude. Click anywhere to take the nearest city,
 * or search for one. Below: the language and the number / date formats.
 *
 * Map and city data: worldmap-dots.png + zones.js (tools/make-installer-map.py,
 * equirectangular, 84°N … 57.75°S). Calamares gives this page `config`
 * (src/modules/locale/Config.h): currentLocation {region, zone, name},
 * setCurrentLocation(region, zone), currentLanguageStatus / currentLCStatus,
 * currentLanguageCode / currentLCCode (writable), supportedLocales.
 */
import QtQuick
import QtQuick.Controls
import "zones.js" as Zones

Rectangle {
    id: page
    color: obsidian

    readonly property color obsidian: "#101114"
    readonly property color graphite: "#1A1C21"
    readonly property color elevated: "#272A31"
    readonly property color line: "#2C2F36"
    readonly property color text: "#F5F3EF"
    readonly property color text2: "#A7A39B"
    readonly property color ember: "#FF7A1A"
    readonly property color solar: "#FFAC55"
    readonly property color glow: "#FFD0A6"

    // the zone Calamares has now, as a row of Zones.list (or null)
    readonly property var here: {
        const loc = config.currentLocation
        if (!loc) return null
        for (const z of Zones.list)
            if (z[0] === loc.region && z[1] === loc.zone) return z
        return null
    }
    property var hover: null

    function onActivate() {}      // Calamares calls these when the page shows / hides
    function onLeave() { search.text = "" }

    function choose(z) {
        if (!z) return
        config.setCurrentLocation(z[0], z[1])
        search.text = ""
    }
    function nearest(lat, lon) {
        let best = null, bd = 1e9
        const k = Math.cos(lat * Math.PI / 180)
        for (const z of Zones.list) {
            let dl = Math.abs(z[5] - lon); if (dl > 180) dl = 360 - dl
            const d = (z[4] - lat) * (z[4] - lat) + (dl * k) * (dl * k)
            if (d < bd) { bd = d; best = z }
        }
        return best
    }
    function find(text) {
        const t = text.trim().toLowerCase()
        if (t.length < 2) return []
        const starts = [], has = []
        for (const z of Zones.list) {
            const c = z[2].toLowerCase(), n = z[3].toLowerCase()
            if (c.startsWith(t)) starts.push(z)
            else if (c.indexOf(t) >= 0 || n.startsWith(t) || (z[0] + "/" + z[1]).toLowerCase().indexOf(t) >= 0) has.push(z)
        }
        return starts.concat(has).slice(0, 7)
    }

    Column {
        id: body
        anchors.fill: parent
        anchors.margins: 28
        anchors.topMargin: 22
        spacing: 16

        Column {
            spacing: 4
            Text {
                text: qsTr("Where are you?")
                color: page.text
                font.family: "Inter"; font.pixelSize: 24; font.weight: Font.DemiBold
            }
            Text {
                text: qsTr("Choose your time zone on the map, or search for a city near you.")
                color: page.text2
                font.family: "Inter"; font.pixelSize: 13
            }
        }

        // ------------------------------------------------------------ map
        Rectangle {
            id: card
            width: parent.width
            height: Math.min(parent.width / map.ratio + 24, body.height - 196)
            radius: 22
            color: "#15171B"
            border.width: 1
            border.color: page.line
            clip: true

            Item {
                id: map
                // keep the map's own proportions inside the card
                readonly property real ratio: 360 / (Zones.north - Zones.south)   // square cells
                width: Math.min(card.width - 24, (card.height - 24) * ratio)
                height: width / ratio
                anchors.centerIn: parent

                function xOf(lon) { return (lon + 180) / 360 * width }
                function yOf(lat) { return (Zones.north - Math.max(Zones.south, Math.min(Zones.north, lat))) / (Zones.north - Zones.south) * height }

                // the longitude band of the chosen city
                Rectangle {
                    visible: !!page.here
                    x: page.here ? map.xOf(page.here[5]) - width / 2 : 0
                    width: map.width / 24
                    height: map.height
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 0.48, 0.1, 0.16) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                }

                Image {
                    anchors.fill: parent
                    source: "worldmap-dots.png"
                    smooth: true
                    mipmap: true
                    opacity: 0.16
                }

                // every city, faintly
                Repeater {
                    model: Zones.list
                    Rectangle {
                        required property var modelData
                        x: map.xOf(modelData[5]) - 1.5
                        y: map.yOf(modelData[4]) - 1.5
                        width: 3; height: 3; radius: 1.5
                        color: page.solar
                        opacity: 0.38
                    }
                }

                // hover: a ghost of the city you would get
                Rectangle {
                    visible: !!page.hover && page.hover !== page.here
                    x: page.hover ? map.xOf(page.hover[5]) - 5 : 0
                    y: page.hover ? map.yOf(page.hover[4]) - 5 : 0
                    width: 10; height: 10; radius: 5
                    color: "transparent"
                    border.width: 2; border.color: page.glow
                    opacity: 0.8
                }
                Rectangle {
                    visible: !!page.hover && page.hover !== page.here
                    readonly property real px: page.hover ? map.xOf(page.hover[5]) : 0
                    readonly property real py: page.hover ? map.yOf(page.hover[4]) : 0
                    x: Math.max(0, Math.min(map.width - width, px - width / 2))
                    y: py > 44 ? py - 34 : py + 14
                    width: hoverText.implicitWidth + 20; height: 24; radius: 12
                    color: Qt.rgba(0.153, 0.165, 0.192, 0.92)
                    border.width: 1; border.color: page.line
                    Text {
                        id: hoverText
                        anchors.centerIn: parent
                        text: page.hover ? page.hover[2] : ""
                        color: page.text; font.family: "Inter"; font.pixelSize: 11
                    }
                }

                // the pin
                Item {
                    id: pin
                    visible: !!page.here
                    x: page.here ? map.xOf(page.here[5]) : 0
                    y: page.here ? map.yOf(page.here[4]) : 0
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                    Rectangle {   // pulse
                        id: pulse
                        anchors.centerIn: parent
                        width: 14; height: 14; radius: width / 2
                        color: "transparent"
                        border.width: 2; border.color: page.ember
                        SequentialAnimation on width {
                            loops: Animation.Infinite
                            NumberAnimation { from: 14; to: 46; duration: 1600; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 300 }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.9; to: 0; duration: 1600; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 300 }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 22; radius: 11
                        color: Qt.rgba(1, 0.48, 0.1, 0.25)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: 6
                        color: page.ember
                        border.width: 2; border.color: "#FFFFFF"
                    }
                }
                // the pin's label, kept inside the map
                Rectangle {
                    id: label
                    visible: !!page.here
                    x: Math.max(0, Math.min(map.width - width, pin.x - width / 2))
                    y: pin.y > 70 ? pin.y - height - 18 : pin.y + 18
                    width: Math.max(labelCity.implicitWidth, labelCountry.implicitWidth) + 32
                    height: 50
                    radius: 16
                    color: Qt.rgba(0.153, 0.165, 0.192, 0.94)
                    border.width: 1; border.color: Qt.rgba(1, 0.48, 0.1, 0.45)
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            id: labelCity
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.here ? page.here[2] : ""
                            color: page.text; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        Text {
                            id: labelCountry
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.here ? page.here[3] : ""
                            color: page.text2; font.family: "Inter"; font.pixelSize: 11
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function at(m) {
                        const lon = m.x / map.width * 360 - 180
                        const lat = Zones.north - m.y / map.height * (Zones.north - Zones.south)
                        return page.nearest(lat, lon)
                    }
                    onPositionChanged: (m) => page.hover = at(m)
                    onExited: page.hover = null
                    onClicked: (m) => page.choose(at(m))
                }
            }
        }

        // ------------------------------------------------------------ search + zone
        Item {
            width: parent.width
            height: 44
            z: 2

            TextField {
                id: search
                width: Math.min(360, parent.width * 0.45)
                height: 44
                leftPadding: 44; rightPadding: 16
                placeholderText: qsTr("Search for a city")
                placeholderTextColor: page.text2
                color: page.text
                selectionColor: page.ember
                font.family: "Inter"; font.pixelSize: 14
                background: Rectangle {
                    radius: 22
                    color: page.graphite
                    border.width: 1
                    border.color: search.activeFocus ? page.ember : page.line
                }
                Text {   // magnifier
                    x: 17; anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"; color: page.text2; font.pixelSize: 19
                }
                readonly property var hits: page.find(text)
                Keys.onReturnPressed: if (hits.length) page.choose(hits[0])
                Keys.onEnterPressed: if (hits.length) page.choose(hits[0])
                Keys.onEscapePressed: text = ""
            }

            Rectangle {   // the zone Calamares will set
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                width: zoneRow.implicitWidth + 28
                radius: 18
                color: Qt.rgba(1, 0.48, 0.1, 0.12)
                border.width: 1; border.color: Qt.rgba(1, 0.48, 0.1, 0.35)
                Row {
                    id: zoneRow
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: page.ember; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: qsTr("Time zone") + "  " + (config.currentLocation
                              ? (config.currentLocation.region + " / " + config.currentLocation.zone).replace(/_/g, " ") : "—")
                        color: page.text; font.family: "Inter"; font.pixelSize: 13
                    }
                }
            }

            // search results, floating over what is below
            Rectangle {
                visible: search.activeFocus && search.hits.length > 0
                y: search.height + 6
                width: search.width
                height: results.contentHeight + 12
                radius: 18
                color: page.elevated
                border.width: 1; border.color: page.line
                ListView {
                    id: results
                    anchors.fill: parent
                    anchors.margins: 6
                    interactive: false
                    model: search.hits
                    delegate: Rectangle {
                        required property var modelData
                        width: results.width; height: 40; radius: 12
                        color: hit.containsMouse ? Qt.rgba(1, 0.48, 0.1, 0.16) : "transparent"
                        Text {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            text: modelData[2]
                            color: page.text; font.family: "Inter"; font.pixelSize: 14
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[3]
                            color: page.text2; font.family: "Inter"; font.pixelSize: 12
                        }
                        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: page.choose(modelData) }
                    }
                }
            }
        }

        // ------------------------------------------------------------ language, formats
        Row {
            width: parent.width
            spacing: 12
            Setting {
                width: (parent.width - 12) / 2
                title: qsTr("Language")
                value: config.currentLanguageStatus
                onChange: { picker.lc = false; picker.open() }
            }
            Setting {
                width: (parent.width - 12) / 2
                title: qsTr("Numbers, dates and currency")
                value: config.currentLCStatus
                onChange: { picker.lc = true; picker.open() }
            }
        }
    }

    component Setting: Rectangle {
        id: st
        property string title
        property string value
        signal change()
        height: 60
        radius: 16
        color: page.graphite
        border.width: 1; border.color: page.line
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 136
            spacing: 2
            Text { text: st.title; color: page.text2; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
            Text { width: parent.width; text: st.value; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: page.text; font.family: "Inter"; font.pixelSize: 12 }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 96; height: 36; radius: 18
            color: chg.pressed ? page.line : chg.containsMouse ? "#33363E" : page.elevated
            border.width: 1; border.color: page.line
            Text { anchors.centerIn: parent; text: qsTr("Change"); color: page.text; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold }
            MouseArea { id: chg; anchors.fill: parent; hoverEnabled: true; onClicked: st.change() }
        }
    }

    // ------------------------------------------------------------ locale picker
    Popup {
        id: picker
        property bool lc: false
        readonly property string current: lc ? config.currentLCCode : config.currentLanguageCode
        anchors.centerIn: parent
        width: Math.min(460, page.width - 60)
        height: Math.min(520, page.height - 40)
        modal: true
        padding: 10
        Overlay.modal: Rectangle { color: "#99000000" }
        background: Rectangle { radius: 22; color: page.graphite; border.width: 1; border.color: page.line }
        onOpened: {
            filter.text = ""
            filter.forceActiveFocus()
            list.positionViewAtIndex(Math.max(0, config.supportedLocales.indexOf(current)), ListView.Center)
        }
        contentItem: Column {
            spacing: 8
            Text {
                leftPadding: 10; topPadding: 6
                text: picker.lc ? qsTr("Numbers, dates and currency") : qsTr("Language")
                color: page.text; font.family: "Inter"; font.pixelSize: 17; font.weight: Font.DemiBold
            }
            TextField {
                id: filter
                width: parent.width; height: 40
                leftPadding: 16
                placeholderText: qsTr("Filter (e.g. de_DE, fr, pt_BR)")
                placeholderTextColor: page.text2
                color: page.text; selectionColor: page.ember
                font.family: "Inter"; font.pixelSize: 13
                background: Rectangle { radius: 20; color: page.obsidian; border.width: 1; border.color: filter.activeFocus ? page.ember : page.line }
            }
            ListView {
                id: list
                width: parent.width
                height: picker.availableHeight - 100
                clip: true
                model: filter.text.length
                       ? config.supportedLocales.filter(l => l.toLowerCase().indexOf(filter.text.toLowerCase()) >= 0)
                       : config.supportedLocales
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData === picker.current
                    width: list.width - 8; height: 38; radius: 12
                    color: on ? Qt.rgba(1, 0.48, 0.1, 0.18) : pick.containsMouse ? page.elevated : "transparent"
                    Text {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: parent.on ? page.solar : page.text
                        font.family: "Inter"; font.pixelSize: 13; font.weight: parent.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: pick
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (picker.lc) config.currentLCCode = modelData
                            else config.currentLanguageCode = modelData
                            picker.close()
                        }
                    }
                }
            }
        }
    }
}
