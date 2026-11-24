// Enclave Shell — Start: search across the top, a category rail on the left
// (Home, All apps, then the app groups, with the account and power at its
// foot) and the chosen page on the right. A full-screen transparent overlay
// above the dock's reserved area, so a click anywhere outside closes it.
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

    property string page: "home"           // home | all | <category>
    readonly property string query: search.text.trim()
    property var results: []
    property var recent: []
    property var groups: []
    property int selected: 0

    readonly property var groupIcons: ({
        "Accessories": "applications-utilities-symbolic",
        "Development": "applications-engineering-symbolic",
        "Education": "applications-science-symbolic",
        "Games": "applications-games-symbolic",
        "Graphics": "applications-graphics-symbolic",
        "Internet": "web-browser-symbolic",
        "Multimedia": "applications-multimedia-symbolic",
        "Office": "x-office-document-symbolic",
        "System": "applications-system-symbolic",
    })

    readonly property var getStarted: [
        { title: "Install Enclave OS on this PC", app: "enclave-install.desktop", live: true },
        { title: "Browse the web", app: "zen.desktop" },
        { title: "Set up your email", app: "org.mozilla.Thunderbird.desktop" },
        { title: "Ask the Enclave Assistant", app: "enclave-assistant.desktop" },
        { title: "Make Enclave yours", app: "enclave-settings.desktop" },
        { title: "Open your files", app: "thunar.desktop" },
    ]

    function open(startPage) {
        page = startPage || "home"
        search.text = ""
        recent = System.recentFiles(6)
        groups = Apps.categories()
        if (!visible) {
            visible = true
            panel.state = "open"
        }
        search.forceActiveFocus()
    }
    function close() { if (visible) panel.state = "closed" }
    function toggle() { visible && panel.state === "open" ? close() : open() }
    function launch(id) { Apps.launch(id); close() }
    function showPinMenu(appId) {
        pinMenu.appId = appId
        pinMenu.pinned = Apps.startPins.indexOf(appId) >= 0
        pinMenu.popup()
    }

    onQueryChanged: { results = Apps.search(query, 14); selected = 0 }

    // Click outside the panel closes Start.
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: panel
        width: Math.min(740, root.width - 24)
        height: Math.min(620, root.height - 16)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - 8
        transformOrigin: Item.Bottom
        state: "closed"

        states: [
            State { name: "open";   PropertyChanges { panel.opacity: 1; panel.scale: 1; slide.y: 0 } },
            State { name: "closed"; PropertyChanges { panel.opacity: 0; panel.scale: 0.98; slide.y: 16 } }
        ]
        transitions: [
            Transition {
                to: "open"
                NumberAnimation { properties: "opacity,scale,y"; duration: Theme.motion.standard; easing.type: Easing.OutCubic }
            },
            Transition {
                to: "closed"
                SequentialAnimation {
                    NumberAnimation { properties: "opacity,scale,y"; duration: Theme.motion.fast; easing.type: Easing.InCubic }
                    ScriptAction { script: root.visible = false }
                }
            }
        ]
        transform: Translate { id: slide }

        Glass { anchors.fill: parent }
        MouseArea { anchors.fill: parent }   // clicks inside stay inside

        SearchField {
            id: search
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            placeholderText: "Search apps, settings and documents"
            Keys.onEscapePressed: {
                if (text !== "") text = ""
                else if (root.page !== "home") root.page = "home"
                else root.close()
            }
            Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
            Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
            onAccepted: if (root.results.length > 0) root.launch(root.results[root.selected].appId)
        }

        // ---------------- the rail ----------------
        Item {
            id: rail
            anchors { left: parent.left; top: search.bottom; bottom: parent.bottom; margins: 12; topMargin: 14 }
            width: 186

            component RailItem: Item {
                id: ri
                property string icon: ""
                property string label: ""
                property bool current: false
                signal clicked()
                width: parent ? parent.width : 186
                height: 34
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.small + 2
                    color: ri.current ? Theme.c.accentSoft : riMouse.containsMouse ? Theme.c.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                    Rectangle {
                        visible: ri.current
                        width: 3; height: 14; radius: 1.5
                        x: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.c.accent
                    }
                }
                Image {
                    id: riIcon
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: ri.icon === "" ? "" : "image://icon/" + ri.icon + "?color="
                            + encodeURIComponent(ri.current ? Theme.c.accent : Theme.c.text)
                }
                Text {
                    anchors { left: riIcon.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                    text: ri.label
                    color: Theme.c.text
                    font.pointSize: 9.5
                    font.weight: ri.current ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                MouseArea { id: riMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ri.clicked() }
            }

            Column {
                width: parent.width
                spacing: 2
                RailItem {
                    icon: "go-home-symbolic"; label: "Home"
                    current: root.query === "" && root.page === "home"
                    onClicked: { search.text = ""; root.page = "home" }
                }
                RailItem {
                    icon: "view-app-grid-symbolic"; label: "All apps"
                    current: root.query === "" && root.page === "all"
                    onClicked: { search.text = ""; root.page = "all" }
                }
                Rectangle { width: parent.width - 16; x: 8; height: 1; color: Theme.c.border; opacity: 0.8 }
                Item { width: 1; height: 2 }
                Repeater {
                    model: root.groups
                    delegate: RailItem {
                        required property string modelData
                        icon: root.groupIcons[modelData] || "applications-other-symbolic"
                        label: modelData
                        current: root.query === "" && root.page === modelData
                        onClicked: { search.text = ""; root.page = modelData }
                    }
                }
            }

            // account and power at the foot of the rail
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 44
                Rectangle { width: parent.width; height: 1; color: Theme.c.border }
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter; verticalCenterOffset: 3 }
                    spacing: 10
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Theme.c.accentSoft
                        clip: true
                        Text { anchors.centerIn: parent; text: System.userInitial; color: Theme.c.accent; font.weight: Font.DemiBold }
                        Image { anchors.fill: parent; visible: System.avatar !== ""; source: System.avatar ? "file://" + System.avatar : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: rail.width - 28 - 10 - 8 - 36
                        text: System.userName
                        color: Theme.c.text
                        font.pointSize: 9.5
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    id: powerButton
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 3 }
                    width: 32; height: 32; radius: 16
                    icon: "system-shutdown-symbolic"; symbolic: true; iconSize: 16
                    tooltip: "Power"
                    onClicked: powerMenu.popup(powerButton, 0, -powerMenu.implicitHeight - 6)
                }
                EmberMenu {
                    id: powerMenu
                    MenuItem { text: "Sleep";     onTriggered: { root.close(); System.suspend() } }
                    MenuItem { text: "Restart";   onTriggered: System.reboot() }
                    MenuItem { text: "Shut down"; onTriggered: System.powerOff() }
                    MenuSeparator {}
                    MenuItem { text: "Sign out";  onTriggered: System.logout() }
                }
            }
        }

        Rectangle {
            id: divider
            anchors { left: rail.right; leftMargin: 12; top: rail.top; bottom: parent.bottom; bottomMargin: 18 }
            width: 1
            color: Theme.c.border
        }

        // ---------------- the page ----------------
        Item {
            id: pageArea
            anchors { left: divider.right; right: parent.right; top: rail.top; bottom: parent.bottom
                      leftMargin: 16; rightMargin: 18; bottomMargin: 14 }

            // ---- home: pinned + recommended ----
            Item {
                id: home
                anchors.fill: parent
                visible: root.query === "" && root.page === "home"

                Text { id: pinnedTitle; text: "Pinned"; color: Theme.c.text; font.pointSize: 10; font.weight: Font.DemiBold }
                GridView {
                    id: pinnedGrid
                    anchors { left: parent.left; right: parent.right; top: pinnedTitle.bottom; topMargin: 10 }
                    height: 3 * cellHeight
                    cellWidth: width / 5
                    cellHeight: 92
                    clip: true
                    interactive: count > 15
                    model: Apps.startPins.map(id => Apps.app(id)).filter(a => a.appId)
                    delegate: AppTile {
                        required property var modelData
                        width: pinnedGrid.cellWidth
                        height: pinnedGrid.cellHeight
                        icon: modelData.icon
                        label: modelData.name
                        onClicked: root.launch(modelData.appId)
                        onRightClicked: root.showPinMenu(modelData.appId)
                    }
                }

                Text {
                    id: recTitle
                    anchors { top: pinnedGrid.bottom; topMargin: 14 }
                    text: root.recent.length ? "Recommended" : "Get started"
                    color: Theme.c.text; font.pointSize: 10; font.weight: Font.DemiBold
                }
                GridView {
                    id: recGrid
                    anchors { left: parent.left; right: parent.right; top: recTitle.bottom; topMargin: 8; bottom: parent.bottom }
                    cellWidth: width / 2
                    cellHeight: 50
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
                            radius: Theme.radius.small + 2
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

            // ---- all apps / a category: two neat columns ----
            Item {
                anchors.fill: parent
                visible: root.query === "" && root.page !== "home"
                Text {
                    id: pageTitle
                    text: root.page === "all" ? "All apps" : root.page
                    color: Theme.c.text; font.pointSize: 10; font.weight: Font.DemiBold
                }
                Text {
                    anchors { right: parent.right; verticalCenter: pageTitle.verticalCenter }
                    text: appGrid.count + (appGrid.count === 1 ? " app" : " apps")
                    color: Theme.c.textSecondary; font.pointSize: 8.5
                }
                GridView {
                    id: appGrid
                    anchors { left: parent.left; right: parent.right; top: pageTitle.bottom; topMargin: 10; bottom: parent.bottom }
                    cellWidth: width / 2
                    cellHeight: 44
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.visible && root.page !== "home" ? Apps.appsIn(root.page === "all" ? "" : root.page) : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: appGrid.cellWidth; height: appGrid.cellHeight
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            radius: Theme.radius.small + 2
                            color: cellMouse.containsMouse ? Theme.c.hover : "transparent"
                        }
                        Image {
                            id: cellIcon
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; sourceSize: Qt.size(52, 52)
                            source: "image://icon/" + cell.modelData.icon
                        }
                        Text {
                            anchors { left: cellIcon.right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: cell.modelData.name
                            color: Theme.c.text; font.pointSize: 9.5
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: cellMouse; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (e) => e.button === Qt.RightButton ? root.showPinMenu(cell.modelData.appId)
                                                                          : root.launch(cell.modelData.appId)
                        }
                        ToolTip.visible: cellMouse.containsMouse && cell.modelData.comment !== ""
                        ToolTip.delay: 800
                        ToolTip.text: cell.modelData.comment
                    }
                }
            }

            // ---- search results ----
            ListView {
                id: list
                anchors.fill: parent
                visible: root.query !== ""
                clip: true
                spacing: 2
                currentIndex: root.selected
                model: root.results
                header: Item {
                    width: list.width
                    height: root.results.length === 0 ? 80 : 4
                    Text {
                        visible: root.results.length === 0
                        anchors.centerIn: parent
                        text: "No results for “" + root.query + "”"
                        color: Theme.c.textSecondary
                    }
                }
                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData
                    width: list.width
                    height: 46
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.small + 2
                        color: row.ListView.isCurrentItem ? Theme.c.accentSoft
                             : rowMouse.containsMouse ? Theme.c.hover : "transparent"
                        Rectangle {
                            visible: row.ListView.isCurrentItem
                            width: 3; height: 16; radius: 1.5
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.c.accent
                        }
                    }
                    Image {
                        id: rowIcon
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; sourceSize: Qt.size(52, 52)
                        source: "image://icon/" + row.modelData.icon
                    }
                    Column {
                        anchors { left: rowIcon.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                        Text { text: row.modelData.name; color: Theme.c.text; font.pointSize: 10 }
                        Text {
                            text: row.modelData.settings ? "Settings" : "App"
                            color: Theme.c.textSecondary; font.pointSize: 8
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => e.button === Qt.RightButton ? root.showPinMenu(row.modelData.appId)
                                                                      : root.launch(row.modelData.appId)
                    }
                }
            }
        }

        EmberMenu {
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
                text: Apps.taskbarPins.indexOf(pinMenu.appId) >= 0 ? "Unpin from dock" : "Pin to dock"
                onTriggered: Apps.pinTaskbar(pinMenu.appId, Apps.taskbarPins.indexOf(pinMenu.appId) < 0)
            }
            MenuItem {
                text: Apps.desktopPins.indexOf(pinMenu.appId) >= 0 ? "Remove from desktop" : "Add to desktop"
                onTriggered: Apps.pinDesktop(pinMenu.appId, Apps.desktopPins.indexOf(pinMenu.appId) < 0)
            }
        }
    }
}
