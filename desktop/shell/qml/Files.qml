// Enclave Files — Enclave's own file manager (enclave-files / enclave-shell
// --files). One window: the places sidebar (your folders, Trash, drives with
// their space), a toolbar (round back / forward / up buttons, the path as
// pills — click the bar to type a path — search, grid or list, sort, new
// folder, details), the files as a grid with picture thumbnails or as a list
// with columns, an optional details panel, and a quiet status line.
// Everything is rounded and Ember: the selection, the buttons, the menus.
//
// Keys: Enter open · Backspace / Alt+Left back · Alt+Right forward · Alt+Up up
//       Ctrl+C / X / V · Delete Move to Trash · F2 rename · Ctrl+A select all
//       Ctrl+Shift+N new folder · Ctrl+L type a path · Ctrl+F search
//       Ctrl+H hidden files · Ctrl+1 / Ctrl+2 grid / list · Ctrl+I details
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Enclave
import "components"

Window {
    id: win
    visible: true
    width: 1120
    height: 700
    minimumWidth: 720
    minimumHeight: 440
    title: FS.title + " – Files"
    color: Theme.c.background

    // ------------------------------------------------------------ state
    property bool grid: String(System.setting("files/view", "grid")) !== "list"
    property bool details: System.setting("files/details", "false") === "true"
    property string query: ""
    property var results: []
    readonly property var shown: query.length ? results : FS.entries
    property var sel: ({})
    property int selRev: 0
    property int anchorIndex: -1
    property string renaming: ""
    property bool editingPath: false
    readonly property var selPaths: { selRev; return Object.keys(sel) }
    readonly property var single: {
        selRev
        const k = Object.keys(sel)
        if (k.length !== 1) return null
        for (const e of shown) if (e.path === k[0]) return e
        return null
    }

    function setGrid(on) { grid = on; System.setSetting("files/view", on ? "grid" : "list") }
    function setDetails(on) { details = on; System.setSetting("files/details", on ? "true" : "false") }
    function isSel(path) { return sel[path] === true }
    function clearSel() { sel = ({}); selRev++ }
    function selectOnly(i) { const s = {}; if (i >= 0 && i < shown.length) s[shown[i].path] = true; sel = s; anchorIndex = i; selRev++; view().currentIndex = i }
    function toggle(i) { const s = Object.assign({}, sel); const p = shown[i].path; if (s[p]) delete s[p]; else s[p] = true; sel = s; anchorIndex = i; selRev++ }
    function range(i) {
        const a = anchorIndex < 0 ? i : anchorIndex
        const s = {}
        for (let k = Math.min(a, i); k <= Math.max(a, i); ++k) s[shown[k].path] = true
        sel = s; selRev++
    }
    function selectAll() { const s = {}; for (const e of shown) s[e.path] = true; sel = s; selRev++ }
    function view() { return grid ? gridView : listView }
    function openSelected() {
        const ps = selPaths
        if (ps.length === 0) return
        for (const p of ps) FS.open(p)
    }
    function trashSelected() {
        if (selPaths.length === 0) return
        if (FS.inTrash) confirm.ask("Delete " + countText(selPaths.length) + " for good?",
                                    "This can’t be undone.", "Delete", () => FS.deleteForever(win.selPaths))
        else FS.trash(selPaths)
        clearSel()
    }
    function startRename() { if (single && !FS.inTrash) renaming = single.path }
    function newFolder() {
        const p = FS.newFolder()
        if (p === "") return
        for (let i = 0; i < shown.length; ++i) if (shown[i].path === p) { selectOnly(i); break }
        renaming = p
    }
    function countText(n) { return n === 1 ? "1 item" : n + " items" }
    function thumb(e) { return e.image ? "file://" + encodeURI(e.path) : "image://icon/" + e.icon }

    Connections {
        target: FS
        function onPathChanged() { win.clearSel(); win.query = ""; search.text = ""; win.renaming = ""; win.editingPath = false; win.anchorIndex = -1 }
        function onMessage(text) { toast.show(text) }
    }
    onQueryChanged: searchDelay.restart()
    Timer { id: searchDelay; interval: 220; onTriggered: win.results = win.query.length ? FS.search(win.query) : [] }

    // ------------------------------------------------------------ keys
    Shortcut { sequences: ["Alt+Left", "Backspace"]; enabled: !win.renaming && !search.activeFocus && !pathField.activeFocus; onActivated: FS.back() }
    Shortcut { sequence: "Alt+Right"; onActivated: FS.forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: FS.up() }
    Shortcut { sequence: "Ctrl+L"; onActivated: { win.editingPath = true; pathField.forceActiveFocus(); pathField.selectAll() } }
    Shortcut { sequence: StandardKey.Find; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: FS.showHidden = !FS.showHidden }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.setGrid(true) }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.setGrid(false) }
    Shortcut { sequence: "Ctrl+I"; onActivated: win.setDetails(!win.details) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: win.newFolder() }
    Shortcut { sequence: "F5"; onActivated: FS.refresh() }
    Shortcut { sequences: [StandardKey.Close, "Ctrl+Q"]; onActivated: Qt.quit() }

    // ------------------------------------------------------------ sidebar
    Rectangle {
        id: sidebar
        width: 236
        height: parent.height
        color: Theme.dark ? Theme.c.surface : Qt.darker(Theme.c.background, 1.025)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.c.border }

        Row {   // the app
            x: 18; y: 18
            spacing: 10
            Rectangle {
                width: 32; height: 32; radius: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.brand.solar }
                    GradientStop { position: 1; color: Theme.brand.ember }
                }
                Image {
                    anchors.centerIn: parent
                    width: 18; height: 18; sourceSize: Qt.size(36, 36)
                    source: "image://icon/folder-symbolic?color=" + encodeURIComponent(String(Theme.c.accentText))
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Files"; color: Theme.c.text
                font.pixelSize: 17; font.weight: Font.DemiBold
            }
        }

        Flickable {
            x: 10; y: 70
            width: parent.width - 20
            height: parent.height - y - 10
            contentHeight: side.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: side
                width: parent.width
                spacing: 2

                SideLabel { text: "Places" }
                Repeater {
                    model: FS.places
                    SideItem {
                        required property var modelData
                        label: modelData.name; icon: modelData.icon; target: modelData.path
                    }
                }
                Item { width: 1; height: 14 }
                SideLabel { text: "Drives"; visible: FS.drives.length > 0 }
                Repeater {
                    model: FS.drives
                    SideItem {
                        required property var modelData
                        label: modelData.name; icon: modelData.icon; target: modelData.path
                        detail: modelData.detail; used: modelData.used
                    }
                }
            }
        }
    }

    component SideLabel: Text {
        leftPadding: 10; topPadding: 4; bottomPadding: 6
        color: Theme.c.textSecondary
        font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.4
    }

    component SideItem: Rectangle {
        id: si
        property string label
        property string icon
        property string target
        property string detail: ""
        property real used: -1
        readonly property bool here: FS.path === target
        width: parent ? parent.width : 200
        height: detail !== "" ? 54 : 36
        radius: 10
        color: here ? Theme.c.accentSoft : siMouse.containsMouse ? Theme.c.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Rectangle {   // ember marker on the folder you are in
            visible: si.here
            x: 0; anchors.verticalCenter: parent.verticalCenter
            width: 3; height: 16; radius: 2; color: Theme.c.accent
        }
        Image {
            x: 12; y: si.detail !== "" ? 9 : (si.height - height) / 2
            width: 20; height: 20; sourceSize: Qt.size(40, 40)
            source: "image://icon/" + si.icon
        }
        Text {
            x: 42; y: si.detail !== "" ? 8 : (si.height - height) / 2
            width: si.width - 52
            text: si.label; elide: Text.ElideRight
            color: Theme.c.text
            font.pixelSize: 13; font.weight: si.here ? Font.DemiBold : Font.Normal
        }
        Rectangle {   // drive space
            visible: si.used >= 0
            x: 42; y: 30; width: si.width - 54; height: 4; radius: 2
            color: Theme.c.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, si.used)); height: parent.height; radius: 2
                color: si.used > 0.9 ? Theme.status.danger : Theme.c.accent
            }
        }
        Text {
            visible: si.detail !== ""
            x: 42; y: 37; width: si.width - 52
            text: si.detail; elide: Text.ElideRight
            color: Theme.c.textSecondary; font.pixelSize: 10
        }
        MouseArea {
            id: siMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (e) => e.button === Qt.MiddleButton ? FS.openInNewWindow(si.target) : FS.go(si.target)
        }
    }

    // ------------------------------------------------------------ main pane
    Item {
        id: pane
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // toolbar
        Item {
            id: toolbar
            width: parent.width
            height: 64

            Row {
                id: nav
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                RoundButton2 { icon: "go-previous-symbolic"; tooltip: "Back"; enabled: FS.canBack; onClicked: FS.back() }
                RoundButton2 { icon: "go-next-symbolic"; tooltip: "Forward"; enabled: FS.canForward; onClicked: FS.forward() }
                RoundButton2 { icon: "go-up-symbolic"; tooltip: "Enclosing folder"; enabled: FS.canUp; onClicked: FS.up() }
            }

            // the path: pills, or a field to type one
            Rectangle {
                id: pathBar
                anchors.left: nav.right; anchors.leftMargin: 10
                anchors.right: tools.left; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 38
                radius: height / 2
                color: Theme.dark ? Theme.c.elevated : Theme.c.surface
                border.width: 1
                border.color: pathField.activeFocus ? Theme.c.accent : Theme.c.border

                MouseArea {   // click the empty part to type a path
                    anchors.fill: parent
                    onClicked: { win.editingPath = true; pathField.forceActiveFocus(); pathField.selectAll() }
                }
                Flickable {
                    id: crumbFlick
                    visible: !win.editingPath
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 5
                    contentWidth: crumbRow.width
                    contentX: Math.max(0, contentWidth - width)
                    interactive: contentWidth > width
                    clip: true
                    Row {
                        id: crumbRow
                        height: parent.height
                        spacing: 2
                        Repeater {
                            model: FS.crumbs
                            Row {
                                required property var modelData
                                required property int index
                                readonly property bool last: index === FS.crumbs.length - 1
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                spacing: 2
                                Image {
                                    visible: index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12; height: 12; sourceSize: Qt.size(24, 24)
                                    source: "image://icon/go-next-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
                                }
                                Rectangle {
                                    height: 28
                                    width: crumbText.implicitWidth + (index === 0 ? 40 : 24)
                                    radius: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: parent.last ? Theme.c.accentSoft : crumbMouse.containsMouse ? Theme.c.hover : "transparent"
                                    Image {
                                        visible: index === 0
                                        x: 10; anchors.verticalCenter: parent.verticalCenter
                                        width: 16; height: 16; sourceSize: Qt.size(32, 32)
                                        source: "image://icon/" + (FS.inTrash ? "user-trash-symbolic" : modelData.path === "/" ? "drive-harddisk-symbolic" : "user-home-symbolic")
                                                + "?color=" + encodeURIComponent(parent.parent.last ? Theme.c.accent : Theme.c.text)
                                    }
                                    Text {
                                        id: crumbText
                                        x: index === 0 ? 30 : 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: parent.parent.last ? Theme.c.accent : Theme.c.text
                                        font.pixelSize: 13
                                        font.weight: parent.parent.last ? Font.DemiBold : Font.Normal
                                    }
                                    MouseArea {
                                        id: crumbMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: FS.go(modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
                TextField {
                    id: pathField
                    visible: win.editingPath
                    anchors.fill: parent
                    leftPadding: 16; rightPadding: 16
                    text: FS.inTrash ? "trash" : FS.path
                    color: Theme.c.text
                    selectionColor: Theme.c.accent
                    selectedTextColor: Theme.c.accentText
                    font.pixelSize: 13
                    background: null
                    onAccepted: { FS.go(text); win.editingPath = false }
                    Keys.onEscapePressed: { win.editingPath = false; text = Qt.binding(() => FS.inTrash ? "trash" : FS.path) }
                    onActiveFocusChanged: if (!activeFocus) win.editingPath = false
                }
            }

            Row {
                id: tools
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                SearchField {
                    id: search
                    width: pane.width < 820 ? 170 : 220; height: 38
                    placeholderText: "Search " + FS.title
                    onTextChanged: win.query = text
                    Keys.onEscapePressed: { text = ""; gridView.forceActiveFocus() }
                }
                // grid | list
                Rectangle {
                    width: 82; height: 38; radius: 19
                    color: Theme.dark ? Theme.c.elevated : Theme.c.surface
                    border.width: 1; border.color: Theme.c.border
                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Segment { icon: "view-grid-symbolic"; on: win.grid; tooltip: "Icons (Ctrl+1)"; onClicked: win.setGrid(true) }
                        Segment { icon: "view-list-symbolic"; on: !win.grid; tooltip: "List (Ctrl+2)"; onClicked: win.setGrid(false) }
                    }
                }
                RoundButton2 { icon: "view-sort-ascending-symbolic"; tooltip: "Sort and view"; onClicked: sortMenu.popup() }
                RoundButton2 { icon: "folder-new-symbolic"; tooltip: "New folder (Ctrl+Shift+N)"; enabled: !FS.inTrash; onClicked: win.newFolder() }
                RoundButton2 { icon: "view-reveal-symbolic"; tooltip: "Details (Ctrl+I)"; checked: win.details; onClicked: win.setDetails(!win.details) }
            }
        }

        // the Trash's own bar
        Rectangle {
            id: trashBar
            visible: FS.inTrash
            anchors.top: toolbar.bottom
            x: 14; width: parent.width - 28 - detailsPane.width
            height: visible ? 48 : 0
            radius: 14
            color: Theme.c.accentSoft
            Text {
                x: 16; anchors.verticalCenter: parent.verticalCenter
                text: FS.entries.length ? "Items here can be restored to where they were, or deleted for good."
                                        : "The Trash is empty."
                color: Theme.c.text; font.pixelSize: 13
            }
            PillButton {
                visible: FS.entries.length > 0
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Empty Trash"; danger: true
                onClicked: confirm.ask("Empty the Trash?", "Everything in it is deleted for good. This can’t be undone.",
                                       "Empty Trash", () => FS.emptyTrash())
            }
        }

        // the files
        Item {
            id: content
            anchors.top: trashBar.visible ? trashBar.bottom : toolbar.bottom
            anchors.topMargin: trashBar.visible ? 8 : 0
            anchors.bottom: status.top
            width: parent.width - detailsPane.width

            MouseArea {   // empty space: clear the selection, or the folder's menu
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                    win.clearSel(); win.renaming = ""
                    view().forceActiveFocus()
                    if (e.button === Qt.RightButton) folderMenu.popup()
                }
            }

            // grid
            GridView {
                id: gridView
                visible: win.grid
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 8
                topMargin: 6; bottomMargin: 12
                clip: true
                focus: win.grid
                model: win.shown
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                cellHeight: 138
                currentIndex: -1
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Keys.onPressed: (e) => win.keys(e, Math.max(1, Math.floor(width / cellWidth)))
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool selected: (win.selRev, win.isSel(modelData.path))
                    width: gridView.cellWidth; height: gridView.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4
                        radius: 16
                        color: tile.selected ? Theme.c.accentSoft : tileMouse.containsMouse ? Theme.c.hover : "transparent"
                        border.width: tile.selected ? 1 : 0
                        border.color: Qt.rgba(Theme.c.accent.r, Theme.c.accent.g, Theme.c.accent.b, 0.55)
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                    }
                    Item {   // icon or thumbnail
                        id: art
                        x: (parent.width - 72) / 2; y: 12
                        width: 72; height: 64
                        opacity: tile.modelData.hidden ? 0.55 : 1
                        Rectangle {   // a soft card behind pictures
                            visible: tile.modelData.image && pic.status === Image.Ready
                            anchors.centerIn: pic
                            width: pic.paintedWidth + 6; height: pic.paintedHeight + 6
                            radius: 8; color: Theme.c.surface
                            border.width: 1; border.color: Theme.c.border
                        }
                        Image {
                            id: pic
                            anchors.centerIn: parent
                            width: tile.modelData.image ? 68 : 60
                            height: tile.modelData.image ? 60 : 60
                            fillMode: Image.PreserveAspectFit
                            asynchronous: String(source).startsWith("file:")   // icons: the icon provider is not thread-safe
                            sourceSize: tile.modelData.image ? Qt.size(160, 160) : Qt.size(120, 120)
                            source: win.thumb(tile.modelData)
                            onStatusChanged: if (status === Image.Error) source = "image://icon/" + tile.modelData.icon
                        }
                    }
                    Text {
                        visible: win.renaming !== tile.modelData.path
                        x: 8; y: 82; width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideMiddle
                        color: Theme.c.text
                        font.pixelSize: 12
                        font.weight: tile.selected ? Font.DemiBold : Font.Normal
                    }
                    RenameField { visible: win.renaming === tile.modelData.path; x: 6; y: 80; width: parent.width - 12; entry: tile.modelData }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent; anchors.margins: 4
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: (e) => win.press(e, tile.index)
                        onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) FS.open(tile.modelData.path) }
                    }
                }
            }

            // list
            Item {
                visible: !win.grid
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                Row {   // columns
                    id: header
                    width: parent.width; height: 32
                    Column2 { title: "Name"; key: "name"; width: header.width - 170 - 100 - 170 }
                    Column2 { title: "Modified"; key: "modified"; width: 170 }
                    Column2 { title: "Size"; key: "size"; width: 100 }
                    Column2 { title: "Kind"; key: "kind"; width: 170 }
                }
                Rectangle { anchors.top: header.bottom; width: parent.width; height: 1; color: Theme.c.border }
                ListView {
                    id: listView
                    anchors.top: header.bottom; anchors.topMargin: 4
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    focus: !win.grid
                    model: win.shown
                    currentIndex: -1
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    Keys.onPressed: (e) => win.keys(e, 1)
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: (win.selRev, win.isSel(modelData.path))
                        width: listView.width; height: 38
                        radius: 10
                        color: selected ? Theme.c.accentSoft : rowMouse.containsMouse ? Theme.c.hover
                             : index % 2 ? Qt.rgba(Theme.c.text.r, Theme.c.text.g, Theme.c.text.b, 0.018) : "transparent"
                        opacity: modelData.hidden ? 0.6 : 1
                        Image {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22; sourceSize: Qt.size(44, 44)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: String(source).startsWith("file:")   // the icon provider is not thread-safe
                            source: win.thumb(row.modelData)
                            onStatusChanged: if (status === Image.Error) source = "image://icon/" + row.modelData.icon
                        }
                        Text {
                            visible: win.renaming !== row.modelData.path
                            x: 42; width: header.width - 170 - 100 - 170 - 50
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name; elide: Text.ElideMiddle
                            color: Theme.c.text; font.pixelSize: 13
                            font.weight: row.selected ? Font.DemiBold : Font.Normal
                        }
                        RenameField { visible: win.renaming === row.modelData.path; x: 38; width: 320; anchors.verticalCenter: parent.verticalCenter; entry: row.modelData }
                        Cell { x: header.width - 170 - 100 - 170; width: 170; text: row.modelData.modifiedText }
                        Cell { x: header.width - 100 - 170; width: 100; text: row.modelData.sizeText }
                        Cell { x: header.width - 170; width: 170; text: row.modelData.kind }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (e) => win.press(e, row.index)
                            onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) FS.open(row.modelData.path) }
                        }
                    }
                }
            }

            // nothing here
            Column {
                visible: win.shown.length === 0 && !FS.inTrash
                anchors.centerIn: parent
                spacing: 10
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72; height: 72; sourceSize: Qt.size(144, 144)
                    source: "image://icon/" + (win.query.length ? "system-search" : "folder")
                    opacity: 0.55
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.query.length ? "Nothing called “" + win.query + "” here" : "This folder is empty"
                    color: Theme.c.textSecondary; font.pixelSize: 14
                }
            }
        }

        // status line
        Item {
            id: status
            anchors.bottom: parent.bottom
            width: parent.width - detailsPane.width; height: 34
            Rectangle { width: parent.width; height: 1; color: Theme.c.border }
            Text {
                x: 16; anchors.verticalCenter: parent.verticalCenter
                text: {
                    const n = win.selPaths.length
                    let t = win.query.length ? win.countText(win.shown.length) + " found" : win.countText(win.shown.length)
                    if (n > 0) t = n + " of " + t + " selected"
                    if (win.single && !win.single.dir) t += " · " + win.single.sizeText
                    return t
                }
                color: Theme.c.textSecondary; font.pixelSize: 12
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                BusyIndicator { visible: FS.busy > 0; running: visible; width: 18; height: 18 }
                Text { visible: FS.busy > 0; text: "Copying…"; color: Theme.c.textSecondary; font.pixelSize: 12 }
                Text { text: FS.freeText; color: Theme.c.textSecondary; font.pixelSize: 12 }
            }
        }
    }

    // ------------------------------------------------------------ details
    Rectangle {
        id: detailsPane
        anchors.right: parent.right
        width: win.details ? 260 : 0
        y: 64; height: parent.height - 64
        clip: true
        color: Theme.dark ? Theme.c.surface : Qt.darker(Theme.c.background, 1.015)
        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        Rectangle { width: 1; height: parent.height; color: Theme.c.border }
        Rectangle { width: parent.width; height: 1; color: Theme.c.border }
        readonly property var info: win.single ? FS.info(win.single.path) : null
        Column {
            x: 20; y: 24; width: 220
            spacing: 14
            Rectangle {
                width: 220; height: 160; radius: 18
                color: Theme.dark ? Theme.c.elevated : Theme.c.surface
                border.width: 1; border.color: Theme.c.border
                Image {
                    anchors.centerIn: parent
                    width: detailsPane.info && detailsPane.info.image ? 196 : 96
                    height: detailsPane.info && detailsPane.info.image ? 136 : 96
                    fillMode: Image.PreserveAspectFit
                            asynchronous: String(source).startsWith("file:")   // the icon provider is not thread-safe
                    sourceSize: Qt.size(400, 300)
                    source: detailsPane.info ? win.thumb(detailsPane.info)
                          : "image://icon/" + (win.selPaths.length > 1 ? "edit-copy" : "folder")
                }
            }
            Text {
                width: 220; wrapMode: Text.Wrap
                text: detailsPane.info ? detailsPane.info.name
                    : win.selPaths.length > 1 ? win.selPaths.length + " items selected" : FS.title
                color: Theme.c.text; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Repeater {
                model: detailsPane.info ? [
                    ["Kind", detailsPane.info.kind], ["Size", detailsPane.info.sizeText],
                    ["Modified", detailsPane.info.modifiedText], ["Created", detailsPane.info.created],
                    ["Where", detailsPane.info.where]] : []
                Column {
                    required property var modelData
                    width: 220; spacing: 2
                    Text { text: modelData[0]; color: Theme.c.textSecondary; font.pixelSize: 11 }
                    Text { width: 220; text: modelData[1]; wrapMode: Text.WrapAnywhere; color: Theme.c.text; font.pixelSize: 13 }
                }
            }
        }
    }

    // ------------------------------------------------------------ pieces
    component RoundButton2: IconButton {
        symbolic: true
        iconSize: 18
        width: 38; height: 38
        radius: 19
    }

    component Segment: IconButton {
        property bool on: false
        symbolic: true
        tint: on ? Theme.c.accent : Theme.c.text
        iconSize: 16
        width: 38; height: 32; radius: 16
        checked: on
    }

    component PillButton: Rectangle {
        id: pb
        property string text
        property bool danger: false
        property bool primary: false
        signal clicked()
        width: pbText.implicitWidth + 36; height: 34; radius: 17
        color: primary ? (pbMouse.pressed ? Theme.brand.burnt : Theme.c.accent)
             : danger && pbMouse.containsMouse ? Theme.status.danger
             : pbMouse.containsMouse ? Theme.c.hover : (Theme.dark ? Theme.c.elevated : Theme.c.surface)
        border.width: primary ? 0 : 1
        border.color: danger ? Qt.rgba(0.898, 0.282, 0.302, 0.6) : Theme.c.border
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Text {
            id: pbText
            anchors.centerIn: parent
            text: pb.text
            color: pb.primary ? Theme.c.accentText : pb.danger && pbMouse.containsMouse ? Theme.c.accentText
                 : pb.danger ? Theme.status.danger : Theme.c.text
            font.pixelSize: 13; font.weight: Font.DemiBold
        }
        MouseArea { id: pbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: pb.clicked() }
    }

    component Column2: Item {
        id: col
        property string title
        property string key
        readonly property bool active: FS.sortKey === key
        height: 32
        Text {
            x: col.key === "name" ? 42 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: col.title + (col.active ? (FS.sortDescending ? "  ↓" : "  ↑") : "")
            color: col.active ? Theme.c.accent : Theme.c.textSecondary
            font.pixelSize: 12; font.weight: Font.DemiBold
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { if (col.active) FS.sortDescending = !FS.sortDescending; else { FS.sortKey = col.key; FS.sortDescending = false } }
        }
    }

    component Cell: Text {
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        color: Theme.c.textSecondary
        font.pixelSize: 12
    }

    component RenameField: TextField {
        id: rf
        property var entry
        height: 30
        horizontalAlignment: Text.AlignHCenter
        color: Theme.c.text
        selectionColor: Theme.c.accent
        selectedTextColor: Theme.c.accentText
        font.pixelSize: 12
        background: Rectangle { radius: 10; color: Theme.dark ? Theme.c.elevated : Theme.c.surface; border.width: 1; border.color: Theme.c.accent }
        onVisibleChanged: if (visible && entry) {
            text = entry.name
            forceActiveFocus()
            const dot = entry.dir ? -1 : text.lastIndexOf(".")
            select(0, dot > 0 ? dot : text.length)
        }
        onAccepted: { FS.rename(entry.path, text); win.renaming = ""; win.view().forceActiveFocus() }
        Keys.onEscapePressed: { win.renaming = ""; win.view().forceActiveFocus() }
        onActiveFocusChanged: if (!activeFocus && visible) { FS.rename(entry.path, text); win.renaming = "" }
    }

    // a press on a file: select (Ctrl toggles, Shift extends), right: its menu,
    // middle: open a folder in a new window
    function press(e, i) {
        view().forceActiveFocus()
        if (e.button === Qt.MiddleButton) { if (shown[i].dir) FS.openInNewWindow(shown[i].path); return }
        if (e.button === Qt.RightButton) {
            if (!isSel(shown[i].path)) selectOnly(i)
            itemMenu.popup()
            return
        }
        if (e.modifiers & Qt.ControlModifier) toggle(i)
        else if (e.modifiers & Qt.ShiftModifier) range(i)
        else selectOnly(i)
    }

    function keys(e, cols) {
        const n = shown.length
        const cur = view().currentIndex
        const ctrl = e.modifiers & Qt.ControlModifier
        const move = (d) => {
            const next = Math.max(0, Math.min(n - 1, (cur < 0 ? 0 : cur + d)))
            if (e.modifiers & Qt.ShiftModifier) { view().currentIndex = next; range(next) } else selectOnly(next)
            view().positionViewAtIndex(next, ListView.Contain)
            e.accepted = true
        }
        if (n > 0 && e.key === Qt.Key_Right && !(e.modifiers & Qt.AltModifier)) return move(cols > 1 ? 1 : 0)
        if (n > 0 && e.key === Qt.Key_Left && !(e.modifiers & Qt.AltModifier)) return move(cols > 1 ? -1 : 0)
        if (n > 0 && e.key === Qt.Key_Down) return move(cols)
        if (n > 0 && e.key === Qt.Key_Up && !(e.modifiers & Qt.AltModifier)) return move(-cols)
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { openSelected(); e.accepted = true }
        else if (e.key === Qt.Key_Delete) {
            if (e.modifiers & Qt.ShiftModifier && selPaths.length)
                confirm.ask("Delete " + countText(selPaths.length) + " for good?", "This skips the Trash and can’t be undone.",
                            "Delete", () => { FS.deleteForever(win.selPaths); win.clearSel() })
            else trashSelected()
            e.accepted = true
        }
        else if (e.key === Qt.Key_F2) { startRename(); e.accepted = true }
        else if (e.key === Qt.Key_Escape) { clearSel(); e.accepted = true }
        else if (ctrl && e.key === Qt.Key_A) { selectAll(); e.accepted = true }
        else if (ctrl && e.key === Qt.Key_C && selPaths.length) { FS.copy(selPaths); e.accepted = true }
        else if (ctrl && e.key === Qt.Key_X && selPaths.length && !FS.inTrash) { FS.cut(selPaths); e.accepted = true }
        else if (ctrl && e.key === Qt.Key_V) { FS.paste(); e.accepted = true }
    }

    // ------------------------------------------------------------ menus
    EmberMenu {
        id: itemMenu
        MenuItem { text: win.selPaths.length > 1 ? "Open " + win.selPaths.length + " items" : "Open"; enabled: !FS.inTrash; onTriggered: win.openSelected() }
        MenuItem { text: "Open in New Window"; visible: !!win.single && win.single.dir; height: visible ? implicitHeight : 0; onTriggered: FS.openInNewWindow(win.single.path) }
        MenuItem { text: "Open in Terminal"; visible: !!win.single && win.single.dir; height: visible ? implicitHeight : 0; onTriggered: FS.openTerminal(win.single.path) }
        MenuSeparator {}
        MenuItem { text: "Cut"; enabled: !FS.inTrash; onTriggered: FS.cut(win.selPaths) }
        MenuItem { text: "Copy"; onTriggered: FS.copy(win.selPaths) }
        MenuItem { text: "Copy Path"; onTriggered: FS.copyPath(win.selPaths) }
        MenuItem { text: "Rename…"; enabled: !!win.single && !FS.inTrash; onTriggered: win.startRename() }
        MenuSeparator {}
        MenuItem { text: "Restore"; visible: FS.inTrash; height: visible ? implicitHeight : 0; onTriggered: { FS.restore(win.selPaths); win.clearSel() } }
        MenuItem { text: FS.inTrash ? "Delete for Good…" : "Move to Trash"; onTriggered: win.trashSelected() }
        MenuSeparator {}
        MenuItem { text: "Details"; onTriggered: win.setDetails(true) }
    }

    EmberMenu {
        id: folderMenu
        MenuItem { text: "New Folder"; enabled: !FS.inTrash; onTriggered: win.newFolder() }
        MenuItem { text: "Paste"; enabled: FS.canPaste; onTriggered: FS.paste() }
        MenuItem { text: "Select All"; onTriggered: win.selectAll() }
        MenuSeparator {}
        MenuItem { text: "Open in Terminal"; enabled: !FS.inTrash; onTriggered: FS.openTerminal() }
        MenuItem { text: FS.showHidden ? "Hide Hidden Files" : "Show Hidden Files"; onTriggered: FS.showHidden = !FS.showHidden }
        MenuItem { text: "Refresh"; onTriggered: FS.refresh() }
    }

    EmberMenu {
        id: sortMenu
        MenuItem { text: "Icons"; checkable: true; checked: win.grid; onTriggered: win.setGrid(true) }
        MenuItem { text: "List"; checkable: true; checked: !win.grid; onTriggered: win.setGrid(false) }
        MenuSeparator {}
        MenuItem { text: "Sort by Name"; checkable: true; checked: FS.sortKey === "name"; onTriggered: FS.sortKey = "name" }
        MenuItem { text: "Sort by Date Modified"; checkable: true; checked: FS.sortKey === "modified"; onTriggered: FS.sortKey = "modified" }
        MenuItem { text: "Sort by Size"; checkable: true; checked: FS.sortKey === "size"; onTriggered: FS.sortKey = "size" }
        MenuItem { text: "Sort by Kind"; checkable: true; checked: FS.sortKey === "kind"; onTriggered: FS.sortKey = "kind" }
        MenuItem { text: "Descending"; checkable: true; checked: FS.sortDescending; onTriggered: FS.sortDescending = !FS.sortDescending }
        MenuSeparator {}
        MenuItem { text: "Show Hidden Files"; checkable: true; checked: FS.showHidden; onTriggered: FS.showHidden = !FS.showHidden }
    }

    // ------------------------------------------------------------ confirm
    Popup {
        id: confirm
        property string title
        property string body
        property string action
        property var run: null
        function ask(t, b, a, fn) { title = t; body = b; action = a; run = fn; open() }
        anchors.centerIn: parent
        width: 400
        modal: true
        padding: 24
        Overlay.modal: Rectangle { color: Theme.c.scrim }
        background: Rectangle {
            radius: 20
            color: Theme.dark ? Theme.c.elevated : Theme.c.surface
            border.width: 1; border.color: Theme.c.border
        }
        contentItem: Column {
            spacing: 8
            Text { width: 352; text: confirm.title; wrapMode: Text.Wrap; color: Theme.c.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { width: 352; text: confirm.body; wrapMode: Text.Wrap; color: Theme.c.textSecondary; font.pixelSize: 13 }
            Item { width: 1; height: 12 }
            Row {
                anchors.right: parent.right
                spacing: 8
                PillButton { text: "Cancel"; onClicked: confirm.close() }
                PillButton { text: confirm.action; danger: true; onClicked: { confirm.close(); if (confirm.run) confirm.run() } }
            }
        }
    }

    // ------------------------------------------------------------ toast
    Rectangle {
        id: toast
        property string text
        function show(t) { text = t; opacity = 1; toastTimer.restart() }
        anchors.horizontalCenter: pane.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 50
        width: toastText.implicitWidth + 40; height: 40; radius: 20
        color: Theme.c.elevated
        border.width: 1; border.color: Theme.c.border
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.standard } }
        Text { id: toastText; anchors.centerIn: parent; text: toast.text; color: Theme.c.text; font.pixelSize: 13 }
        Timer { id: toastTimer; interval: 3500; onTriggered: toast.opacity = 0 }
    }

    Component.onCompleted: gridView.forceActiveFocus()
}
