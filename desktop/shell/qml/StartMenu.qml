// Enclave Shell — Start: search, Pinned, Recommended, All apps, account and
// power. A full-screen transparent overlay above the taskbar's reserved
// area, so a click anywhere outside the panel closes it.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: false
    color: "transparent"
    title: "Enclave Start"

    LayerShell.Window.scope: "enclave-start"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    property string page: "home"           // home | all
    readonly property string query: search.text.trim()
    property var results: []
    property var recent: []
    property int selected: 0

    readonly property var getStarted: [
        { title: "Install Enclave OS on this PC", app: "enclave-install.desktop", live: true },
        { title: "Browse the web", app: "zen.desktop" },
        { title: "Set up your email", app: "org.mozilla.Thunderbird.desktop" },
        { title: "Ask the Enclave Assistant", app: "enclave-assistant.desktop" },
        { title: "Make Enclave yours", app: "xfce-settings-manager.desktop" },
        { title: "Open your files", app: "thunar.desktop" },
    ]

    function open() {
        if (visible) return
        page = "home"
        search.text = ""
        recent = System.recentFiles(6)
        visible = true
        panel.state = "open"
        search.forceActiveFocus()
    }
    function close() { if (visible) panel.state = "closed" }
    function toggle() { visible && panel.state === "open" ? close() : open() }
    function launch(id) { Apps.launch(id); close() }

    onQueryChanged: { results = Apps.search(query, 14); selected = 0 }

    // Click outside the panel closes Start.
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: panel
        width: Math.min(660, root.width - 24)
        height: Math.min(700, root.height - 24)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - 12
        state: "closed"

        states: [
            State { name: "open";   PropertyChanges { panel.opacity: 1; panel.anchors.verticalCenterOffset: 0; slide.y: 0 } },
            State { name: "closed"; PropertyChanges { panel.opacity: 0; slide.y: 24 } }
        ]
        transitions: [
            Transition {
                to: "open"
                NumberAnimation { properties: "opacity,y"; duration: Theme.motion.standard; easing.type: Easing.OutCubic }
            },
            Transition {
                to: "closed"
                SequentialAnimation {
                    NumberAnimation { properties: "opacity,y"; duration: Theme.motion.fast; easing.type: Easing.InCubic }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
        transform: Translate { id: slide }

        // soft shadow (works with the software renderer too)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.fill: parent
                anchors.margins: -(index + 1) * 2
                anchors.topMargin: -(index + 1) * 2 + 4
                radius: Theme.radius.large + (index + 1) * 2
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.14 : 0.05) / (index + 1))
            }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radius.large
            color: Theme.c.glass
            border.width: 1
            border.color: Theme.c.border
            MouseArea { anchors.fill: parent }   // swallow clicks inside the panel

            SearchField {
                id: search
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
                placeholderText: "Search for apps, settings and documents"
                Keys.onEscapePressed: {
                    if (text !== "") text = ""
                    else if (root.page !== "home") root.page = "home"
                    else root.close()
                }
                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
                Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                onAccepted: if (root.results.length > 0) root.launch(root.results[root.selected].appId)
            }

            // ---------------- home ----------------
            Item {
                id: home
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: footer.top; margins: 28; topMargin: 20 }
                visible: root.query === "" && root.page === "home"

                Text { id: pinnedTitle; text: "Pinned"; color: Theme.c.text; font.pointSize: 10; font.weight: Font.DemiBold }
                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: pinnedTitle.verticalCenter
                    text: "All apps  ›"
                    flat: true
                    font.pointSize: 9
                    onClicked: root.page = "all"
                    contentItem: Text { text: parent.text; font: parent.font; color: Theme.c.text }
                    background: Rectangle { radius: Theme.radius.small; color: parent.hovered ? Theme.c.pressed : Theme.c.hover }
                }

                GridView {
                    id: pinnedGrid
                    anchors { left: parent.left; right: parent.right; top: pinnedTitle.bottom; topMargin: 12 }
                    height: 3 * cellHeight
                    cellWidth: width / 6
                    cellHeight: 84
                    clip: true
                    interactive: count > 18
                    model: Apps.startPins.map(id => Apps.app(id)).filter(a => a.appId)
                    delegate: AppTile {
                        required property var modelData
                        width: pinnedGrid.cellWidth
                        height: pinnedGrid.cellHeight
                        icon: modelData.icon
                        label: modelData.name
                        onClicked: root.launch(modelData.appId)
                        onRightClicked: { pinMenu.appId = modelData.appId; pinMenu.pinned = true; pinMenu.popup() }
                    }
                }

                Text {
                    id: recTitle
                    anchors { top: pinnedGrid.bottom; topMargin: 16 }
                    text: root.recent.length ? "Recommended" : "Get started"
                    color: Theme.c.text; font.pointSize: 10; font.weight: Font.DemiBold
                }

                GridView {
                    id: recGrid
                    anchors { left: parent.left; right: parent.right; top: recTitle.bottom; topMargin: 10; bottom: parent.bottom }
                    cellWidth: width / 2
                    cellHeight: 52
                    clip: true
                    interactive: false
                    model: root.recent.length ? root.recent
                         : root.getStarted.filter(g => (!g.live || System.live) && Apps.app(g.app).appId)
                    delegate: Item {
                        id: rec
                        required property var modelData
                        readonly property var app: modelData.app ? Apps.app(modelData.app) : null
                        width: recGrid.cellWidth; height: recGrid.cellHeight
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            radius: Theme.radius.small
                            color: recMouse.containsMouse ? Theme.c.hover : "transparent"
                        }
                        Image {
                            id: recIcon
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; sourceSize: Qt.size(56, 56)
                            source: "image://icon/" + (rec.app ? rec.app.icon : rec.modelData.icon)
                        }
                        Column {
                            anchors { left: recIcon.right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; text: rec.modelData.title; color: Theme.c.text; font.pointSize: 9; elide: Text.ElideRight }
                            Text { width: parent.width; text: rec.app ? rec.app.name : rec.modelData.subtitle; color: Theme.c.textSecondary; font.pointSize: 8; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: recMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (rec.app) root.launch(rec.app.appId)
                                else { System.openUrl(rec.modelData.url); root.close() }
                            }
                        }
                    }
                }
            }

            // ---------------- all apps / search results ----------------
            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: footer.top; margins: 20; topMargin: 16 }
                visible: !home.visible
                clip: true
                spacing: 2
                currentIndex: root.query !== "" ? root.selected : -1
                model: root.query !== "" ? root.results : Apps
                section.property: root.query !== "" ? "" : "letter"
                section.delegate: Text {
                    required property string section
                    text: section; leftPadding: 12; topPadding: 10; bottomPadding: 4
                    color: Theme.c.accent; font.pointSize: 9; font.weight: Font.DemiBold
                }
                header: Item {
                    width: list.width
                    height: root.query !== "" && root.results.length === 0 ? 80 : (root.query === "" ? 36 : 4)
                    Text {
                        visible: root.query !== "" && root.results.length === 0
                        anchors.centerIn: parent
                        text: "No results for “" + root.query + "”"
                        color: Theme.c.textSecondary
                    }
                    Button {
                        visible: root.query === ""
                        anchors.right: parent.right
                        text: "‹  Back"
                        flat: true
                        font.pointSize: 9
                        onClicked: root.page = "home"
                        contentItem: Text { text: parent.text; font: parent.font; color: Theme.c.text }
                        background: Rectangle { radius: Theme.radius.small; color: parent.hovered ? Theme.c.pressed : Theme.c.hover }
                    }
                }
                delegate: Item {
                    id: row
                    required property int index
                    required property var model
                    readonly property var entry: root.query !== "" ? model.modelData : model
                    width: list.width
                    height: 44
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.small
                        color: row.ListView.isCurrentItem ? Theme.c.accentSoft
                             : rowMouse.containsMouse ? Theme.c.hover : "transparent"
                        Rectangle {
                            visible: row.ListView.isCurrentItem
                            width: 3; height: 16; radius: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.c.accent
                        }
                    }
                    Image {
                        id: rowIcon
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; sourceSize: Qt.size(48, 48)
                        source: "image://icon/" + row.entry.icon
                    }
                    Column {
                        anchors { left: rowIcon.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                        Text { text: row.entry.name; color: Theme.c.text; font.pointSize: 10 }
                        Text {
                            visible: root.query !== ""
                            text: row.entry.settings ? "Settings" : "App"
                            color: Theme.c.textSecondary; font.pointSize: 8
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => {
                            if (e.button === Qt.RightButton) {
                                pinMenu.appId = row.entry.appId
                                pinMenu.pinned = Apps.startPins.indexOf(row.entry.appId) >= 0
                                pinMenu.popup()
                            } else root.launch(row.entry.appId)
                        }
                    }
                }
            }

            // ---------------- footer: account + power ----------------
            Rectangle {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 64
                color: Theme.c.hover
                bottomLeftRadius: Theme.radius.large
                bottomRightRadius: Theme.radius.large
                Rectangle { width: parent.width; height: 1; color: Theme.c.border }

                Row {
                    anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: Theme.brand.ember
                        clip: true
                        Text { anchors.centerIn: parent; text: System.userInitial; color: "white"; font.weight: Font.DemiBold }
                        Image { anchors.fill: parent; visible: System.avatar !== ""; source: System.avatar ? "file://" + System.avatar : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: System.userName; color: Theme.c.text }
                }

                Row {
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    IconButton {
                        icon: "emblem-system-symbolic"; symbolic: true; iconSize: 18
                        tooltip: "Settings"
                        onClicked: root.launch("xfce-settings-manager.desktop")
                    }
                    IconButton {
                        id: powerButton
                        icon: "system-shutdown-symbolic"; symbolic: true; iconSize: 18
                        tooltip: "Power"
                        onClicked: powerMenu.open()
                        Menu {
                            id: powerMenu
                            y: -height - 6
                            MenuItem { text: "Sleep";     onTriggered: System.suspend() }
                            MenuItem { text: "Restart";   onTriggered: System.reboot() }
                            MenuItem { text: "Shut down"; onTriggered: System.powerOff() }
                            MenuSeparator {}
                            MenuItem { text: "Sign out";  onTriggered: System.logout() }
                        }
                    }
                }
            }
        }

        Menu {
            id: pinMenu
            property string appId: ""
            property bool pinned: false
            MenuItem {
                text: pinMenu.pinned ? "Unpin from Start" : "Pin to Start"
                onTriggered: Apps.pinStart(pinMenu.appId, !pinMenu.pinned)
            }
            MenuItem {
                text: "Move to front"
                visible: pinMenu.pinned
                height: visible ? implicitHeight : 0
                onTriggered: Apps.moveStartPinToFront(pinMenu.appId)
            }
            MenuItem {
                text: Apps.taskbarPins.indexOf(pinMenu.appId) >= 0 ? "Unpin from taskbar" : "Pin to taskbar"
                onTriggered: Apps.pinTaskbar(pinMenu.appId, Apps.taskbarPins.indexOf(pinMenu.appId) < 0)
            }
        }
    }
}
