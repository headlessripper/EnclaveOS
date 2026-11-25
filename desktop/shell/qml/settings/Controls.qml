// Enclave Settings — the building blocks every page is made of, in one place:
//   Page      scrolling page with a title and a lead line
//   Group     a titled card of rows (macOS-style grouped form)
//   Field     one row: optional icon tile, title, subtitle, a control on the right
//   Switch    the Ember switch (orange when on)
//   Segmented a row of mutually exclusive choices
//   Button    primary (ember) or quiet
//   Choice    a drop-down: shows the current label, opens an Ember menu
//   Meter     a thin usage bar
//   Tile      a rounded icon tile (graphite, or ember when it marks something live)
// Use as `Controls.Page`, `Controls.Group`... after `import "." as Controls`.
import QtQml
import QtQuick
import QtQuick.Controls as T
import Enclave
import "../components"

QtObject {
    component Page: Flickable {
        id: page
        property string title: ""
        property string lead: ""
        property var settings: null          // the Settings window (applied(), page)
        default property alias content: body.data
        contentWidth: width
        contentHeight: body.y + body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        T.ScrollBar.vertical: T.ScrollBar { policy: T.ScrollBar.AsNeeded }

        Column {
            id: head
            x: 36; y: 30
            width: page.width - 72
            spacing: 4
            Text {
                text: page.title
                color: Theme.c.text
                font.pointSize: 19
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: page.lead
                color: Theme.c.textSecondary
                font.pointSize: 9.5
                wrapMode: Text.WordWrap
            }
        }
        Column {
            id: body
            x: 36
            y: head.y + head.height + 22
            width: Math.min(page.width - 72, 760)
            spacing: 22
        }
    }

    component Group: Column {
        id: group
        property string title: ""
        property string note: ""
        default property alias rows: card.data
        width: parent ? parent.width : 400
        spacing: 8
        Text {
            visible: group.title !== ""
            leftPadding: 4
            text: group.title
            color: Theme.c.textSecondary
            font.pointSize: 9
            font.weight: Font.DemiBold
        }
        Rectangle {
            width: parent.width
            height: card.height
            radius: Theme.radius.medium + 2
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border
            Column { id: card; width: parent.width }
        }
        Text {
            visible: group.note !== ""
            width: parent.width
            leftPadding: 4
            text: group.note
            color: Theme.c.textSecondary
            font.pointSize: 8.5
            wrapMode: Text.WordWrap
        }
    }

    component Field: Item {
        id: field
        property string icon: ""
        property bool iconLive: false        // ember tile: this thing is on / current
        property string title: ""
        property string subtitle: ""
        property bool link: false            // chevron, whole row clickable
        property bool clickable: link
        default property alias control: slot.data
        readonly property bool isField: true
        signal clicked()
        width: parent ? parent.width : 400
        height: subtitle !== "" ? 62 : 52
        // a hairline above every row but the first visible one
        readonly property bool first: {
            if (!parent) return true
            for (const c of parent.children)
                if (c.visible && c.isField) return c === field
            return true
        }
        Rectangle {
            visible: !field.first
            x: field.icon !== "" ? 56 : 16
            width: parent.width - x
            height: 1
            color: Theme.c.border
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius.medium
            visible: field.clickable
            color: rowMouse.pressed ? Theme.c.pressed : rowMouse.containsMouse ? Theme.c.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: field.clickable
            hoverEnabled: true
            cursorShape: field.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: field.clicked()
        }
        Tile {
            id: tile
            visible: field.icon !== ""
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            icon: field.icon
            live: field.iconLive
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: field.icon !== "" ? 56 : 16
            width: slot.x - x - 12
            spacing: 2
            Text {
                width: parent.width
                text: field.title
                color: Theme.c.text
                font.pointSize: 10
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: field.subtitle
                color: Theme.c.textSecondary
                font.pointSize: 8.5
                elide: Text.ElideRight
            }
        }
        Item {
            id: slot
            anchors { right: chevron.visible ? chevron.left : parent.right; rightMargin: chevron.visible ? 6 : 16
                      verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }
        Image {
            id: chevron
            visible: field.link
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: 14; height: 14
            sourceSize: Qt.size(28, 28)
            source: "image://icon/go-next-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
        }
    }

    component Tile: Rectangle {
        property string icon: ""
        property bool live: false
        property int size: 28
        width: size; height: size
        radius: Math.round(size * 0.3)
        color: live ? Theme.c.accent : Theme.c.elevated
        Behavior on color { ColorAnimation { duration: Theme.motion.standard } }
        Image {
            anchors.centerIn: parent
            width: Math.round(parent.size * 0.56); height: width
            sourceSize: Qt.size(width * 2, width * 2)
            source: parent.icon === "" ? "" : "image://icon/" + parent.icon + "?color="
                    + encodeURIComponent(parent.live ? Theme.c.accentText : Theme.c.text)
        }
    }

    component Switch: Item {
        id: sw
        property bool checked: false
        signal toggled(bool on)
        width: 42; height: 24
        opacity: enabled ? 1 : 0.45
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Theme.c.accent : Theme.c.pressed
            border.width: sw.checked ? 0 : 1
            border.color: Theme.c.border
            Behavior on color { ColorAnimation { duration: Theme.motion.standard } }
        }
        Rectangle {
            width: 20; height: 20; radius: 10
            y: 2
            x: sw.checked ? sw.width - width - 2 : 2
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.08)
            Behavior on x { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked) }
        }
    }

    component Segmented: Rectangle {
        id: seg
        property var options: []             // [{ label, value }]
        property var value
        signal picked(var value)
        height: 30
        width: segRow.width + 4
        radius: Theme.radius.small + 3
        color: Theme.c.hover
        border.width: 1
        border.color: Theme.c.border
        Row {
            id: segRow
            x: 2; y: 2
            Repeater {
                model: seg.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: seg.value === modelData.value
                    width: Math.max(64, segLabel.implicitWidth + 24)
                    height: 26
                    radius: Theme.radius.small + 1
                    color: on ? (Theme.dark ? Theme.c.elevated : Theme.c.surface) : "transparent"
                    border.width: on ? 1 : 0
                    border.color: Theme.c.border
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.on ? Theme.c.text : Theme.c.textSecondary
                        font.pointSize: 9
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { seg.value = modelData.value; seg.picked(modelData.value) }
                    }
                }
            }
        }
    }

    component Button: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        height: 32
        width: btnRow.width + 28
        radius: Theme.radius.small + 3
        opacity: enabled ? 1 : 0.45
        color: primary ? (btnMouse.pressed ? Theme.brand.burnt : Theme.c.accent)
             : btnMouse.pressed ? Theme.c.pressed : btnMouse.containsMouse ? Theme.c.hover : Theme.c.surface
        border.width: primary ? 0 : 1
        border.color: Theme.c.border
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 6
            Image {
                visible: btn.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                sourceSize: Qt.size(28, 28)
                source: btn.icon === "" ? "" : "image://icon/" + btn.icon + "?color=" + encodeURIComponent(btnText.color)
            }
            Text {
                id: btnText
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                color: btn.primary ? Theme.c.accentText : btn.danger ? Theme.status.danger : Theme.c.text
                font.pointSize: 9.5
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Choice: Rectangle {
        id: choice
        property var options: []             // [{ label, value }]
        property var value
        signal picked(var value)
        readonly property string label: {
            for (const o of options) if (o.value === value) return o.label
            return options.length ? "Choose…" : "—"
        }
        height: 32
        width: Math.min(280, Math.max(150, choiceText.implicitWidth + 44))
        radius: Theme.radius.small + 3
        color: choiceMouse.containsMouse || menu.visible ? Theme.c.hover : Theme.c.surface
        border.width: 1
        border.color: menu.visible ? Theme.c.accent : Theme.c.border
        Text {
            id: choiceText
            anchors { left: parent.left; leftMargin: 12; right: arrow.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            text: choice.label
            color: Theme.c.text
            font.pointSize: 9.5
            elide: Text.ElideRight
        }
        Image {
            id: arrow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            width: 12; height: 12
            sourceSize: Qt.size(24, 24)
            source: "image://icon/pan-down-symbolic?color=" + encodeURIComponent(Theme.c.textSecondary)
        }
        MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.popup(choice, 0, choice.height + 4)
        }
        EmberMenu {
            id: menu
            Instantiator {
                model: choice.options
                delegate: T.MenuItem {
                    required property var modelData
                    text: modelData.label
                    checkable: true
                    checked: choice.value === modelData.value
                    onTriggered: { choice.value = modelData.value; choice.picked(modelData.value) }
                }
                onObjectAdded: (i, o) => menu.insertItem(i, o)
                onObjectRemoved: (i, o) => menu.removeItem(o)
            }
        }
    }

    component Meter: Rectangle {
        property real value: 0               // 0..1
        property color tone: value > 0.9 ? Theme.status.danger : Theme.c.accent
        height: 6
        radius: 3
        color: Theme.c.pressed
        Rectangle {
            height: parent.height
            radius: 3
            width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, parent.value)))
            color: parent.tone
            Behavior on width { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutCubic } }
        }
    }

    component Input: T.TextField {
        implicitWidth: 220
        implicitHeight: 32
        leftPadding: 12
        rightPadding: 12
        color: Theme.c.text
        placeholderTextColor: Theme.c.textSecondary
        selectionColor: Theme.brand.glow
        selectedTextColor: Theme.c.text
        font.pointSize: 9.5
        background: Rectangle {
            radius: Theme.radius.small + 3
            color: Theme.c.surface
            border.width: 1
            border.color: parent.activeFocus ? Theme.c.accent : Theme.c.border
        }
    }

    // a quiet status line under a control ("Connecting…", errors)
    component Note: Text {
        color: Theme.c.textSecondary
        font.pointSize: 8.5
        wrapMode: Text.WordWrap
    }
}
