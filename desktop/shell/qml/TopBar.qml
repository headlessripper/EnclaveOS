// Enclave Shell — the top bar: the Enclave mark on the left (opens Start),
// "Search anything" in the true centre (Super+Space), and the status icons and
// date on the right (Control Center and the calendar drop down from here).
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave
import "components"

Window {
    id: root
    visible: true
    color: "transparent"
    title: "Enclave Top Bar"
    height: Theme.topBarHeight
    width: 1280

    property Status status
    property bool startOpen: false
    property bool controlCenterOpen: false
    property bool calendarOpen: false
    signal startRequested()
    signal searchRequested()
    signal controlCenterRequested()
    signal calendarRequested()

    LayerShell.Window.scope: "enclave-topbar"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                               | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: Theme.topBarHeight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // the bar: glass with a hairline underneath
    Rectangle {
        anchors.fill: parent
        color: Theme.c.glass
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.c.border }
    }

    // a hover/press wash shared by every bar button
    component BarButton: Item {
        id: bb
        property bool checked: false
        signal clicked()
        height: Theme.topBarHeight - 8
        y: 4
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.small + 2
            color: bbMouse.pressed ? Theme.c.pressed : (bbMouse.containsMouse || bb.checked) ? Theme.c.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        }
        MouseArea { id: bbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: bb.clicked() }
    }

    // ---- left: the Enclave mark ----
    BarButton {
        id: brand
        x: 8
        width: brandRow.width + 20
        checked: root.startOpen
        onClicked: root.startRequested()
        Row {
            id: brandRow
            anchors.centerIn: parent
            spacing: 8
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20
                sourceSize: Qt.size(40, 40)
                source: "file:///usr/share/enclave/" + (Theme.dark ? "enclave-logo-dark.svg" : "enclave-logo.svg")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Enclave"
                color: Theme.c.text
                font.pointSize: 10.5
                font.weight: Font.DemiBold
            }
        }
    }

    // the window in front, by name (its title bar is gone, as on macOS)
    Text {
        id: activeTitle
        anchors { left: brand.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: Math.max(0, searchPill.x - x - 24)
        visible: Windows.activeIndex >= 0 && text !== "" && width > 40
        text: Windows.activeTitle
        color: Theme.c.textSecondary
        font.pointSize: 9.5
        elide: Text.ElideRight
    }

    // ---- centre: search anything ----
    Item {
        id: searchPill
        width: Math.min(520, root.width - 2 * Math.max(brand.width, right.width) - 64)
        height: root.height - 10
        anchors.centerIn: parent
        visible: width > 160
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: searchMouse.containsMouse ? Theme.c.pressed : Theme.c.hover
            border.width: 1
            border.color: searchMouse.containsMouse ? Theme.c.accent : Theme.c.border
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }
        }
        Image {
            id: glass
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: "image://icon/system-search-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
        }
        Text {
            anchors { left: glass.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: "Search anything…"
            color: Theme.c.textSecondary
            font.pointSize: 9.5
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: keyHint.implicitWidth + 12
            height: parent.height - 10
            radius: Theme.radius.small
            color: "transparent"
            border.width: 1
            border.color: Theme.c.border
            Text {
                id: keyHint
                anchors.centerIn: parent
                text: "Super  Space"
                color: Theme.c.textSecondary
                font.pointSize: 8
            }
        }
        MouseArea { id: searchMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.searchRequested() }
    }

    // ---- right: status and the date ----
    Row {
        id: right
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 4

        BarButton {
            width: statusRow.width + 20
            checked: root.controlCenterOpen
            onClicked: root.controlCenterRequested()
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: root.status
                           ? [root.status.dnd ? "notifications-disabled-symbolic" : "",
                              root.status.netIcon,
                              root.status.hasAudio ? root.status.volumeIcon : "",
                              root.status.batteryIcon].filter(i => i !== "")
                           : []
                    delegate: Image {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        sourceSize: Qt.size(32, 32)
                        source: "image://icon/" + modelData + "?color=" + encodeURIComponent(Theme.c.text)
                    }
                }
                Text {
                    visible: !!root.status && root.status.battery >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.status ? root.status.battery + "%" : ""
                    color: Theme.c.text
                    font.pointSize: 9
                }
            }
        }

        BarButton {
            id: clock
            width: clockText.implicitWidth + 20
            checked: root.calendarOpen
            onClicked: root.calendarRequested()
            property date now: new Date()
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clock.now = new Date()
            }
            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatDate(clock.now, "ddd d MMM") + "   " + Qt.formatTime(clock.now, "HH:mm")
                color: Theme.c.text
                font.pointSize: 9.5
                font.weight: Font.Medium
            }
        }
    }
}
