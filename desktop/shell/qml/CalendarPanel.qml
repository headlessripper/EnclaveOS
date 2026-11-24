// Enclave Shell — the calendar flyout, dropped from the top bar clock: today at a
// glance, then a month you can page through. Today is the one orange mark.
import QtQuick
import QtQuick.Controls
import Enclave
import "components"

Flyout {
    id: root
    scope: "enclave-calendar"
    title: "Enclave Calendar"
    panelWidth: 320
    padding: 18

    property date now: new Date()
    property int month: now.getMonth()
    property int year: now.getFullYear()

    onAboutToOpen: { now = new Date(); month = now.getMonth(); year = now.getFullYear() }

    function page(delta) {
        let m = month + delta, y = year
        if (m < 0) { m = 11; --y }
        if (m > 11) { m = 0; ++y }
        month = m; year = y
    }

    Timer {
        interval: 1000; running: root.visible; repeat: true
        onTriggered: root.now = new Date()
    }

    Column {
        width: parent.width
        spacing: 12

        // ---- today ----
        Column {
            width: parent.width
            spacing: 2
            Text {
                text: Qt.formatTime(root.now, "HH:mm")
                color: Theme.c.text
                font.pointSize: 26
                font.weight: Font.Light
            }
            Text {
                text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                color: Theme.c.textSecondary
                font.pointSize: 9.5
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.c.border }

        // ---- month header ----
        Item {
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                color: Theme.c.text
                font.pointSize: 10.5
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                IconButton {
                    width: 28; height: 28; radius: 14; iconSize: 14; symbolic: true
                    icon: "go-previous-symbolic"; tooltip: "Previous month"
                    onClicked: root.page(-1)
                }
                IconButton {
                    width: 28; height: 28; radius: 14; iconSize: 8; symbolic: true
                    icon: "media-record-symbolic"; tooltip: "Today"
                    tint: Theme.c.accent
                    onClicked: { root.month = root.now.getMonth(); root.year = root.now.getFullYear() }
                }
                IconButton {
                    width: 28; height: 28; radius: 14; iconSize: 14; symbolic: true
                    icon: "go-next-symbolic"; tooltip: "Next month"
                    onClicked: root.page(1)
                }
            }
        }

        // ---- the month ----
        Column {
            width: parent.width
            spacing: 4
            DayOfWeekRow {
                width: parent.width
                delegate: Text {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    color: Theme.c.textSecondary
                    font.pointSize: 8.5
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            MonthGrid {
                id: grid
                width: parent.width
                height: 6 * 36
                month: root.month
                year: root.year
                spacing: 0
                delegate: Item {
                    id: day
                    required property var model
                    readonly property bool inMonth: model.month === grid.month
                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 15
                        color: day.model.today ? Theme.c.accent
                             : dayMouse.containsMouse && day.inMonth ? Theme.c.hover : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: day.model.day
                        color: day.model.today ? Theme.c.accentText : Theme.c.text
                        opacity: day.inMonth ? 1 : 0.35
                        font.pointSize: 9
                        font.weight: day.model.today ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
