// A flyout panel (Control Center, calendar): a full-screen transparent
// overlay above the taskbar's reserved area holding one glass card, so a
// click outside folds it. Children go into the card; its height follows them.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Enclave

Window {
    id: root
    visible: false
    color: "transparent"

    property string scope: "enclave-flyout"
    property int panelWidth: 340
    property int padding: 14
    property string align: "right"          // right | centre
    property string edge: "top"             // top (drops from the top bar) | bottom
    default property alias content: body.data
    readonly property bool shown: visible && panel.state === "open"
    signal aboutToOpen()

    LayerShell.Window.scope: root.scope
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    function open() {
        if (visible) return
        aboutToOpen()
        visible = true
        panel.state = "open"
        requestActivate()
        body.forceActiveFocus()
    }
    function close() { if (visible) panel.state = "closed" }
    function toggle() { shown ? close() : open() }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        id: panel
        width: Math.min(root.panelWidth, root.width - 16)
        height: body.childrenRect.height + root.padding * 2
        x: root.align === "right" ? root.width - width - 8 : (root.width - width) / 2
        y: root.edge === "top" ? 8 : root.height - height - 8
        transformOrigin: root.edge === "top" ? (root.align === "right" ? Item.TopRight : Item.Top)
                                             : (root.align === "right" ? Item.BottomRight : Item.Bottom)
        state: "closed"
        states: [
            State { name: "open";   PropertyChanges { panel.opacity: 1; panel.scale: 1; slide.y: 0 } },
            State { name: "closed"; PropertyChanges { panel.opacity: 0; panel.scale: 0.97; slide.y: root.edge === "top" ? -10 : 10 } }
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

        Item {
            id: body
            x: root.padding
            y: root.padding
            width: panel.width - root.padding * 2
            height: childrenRect.height
            focus: true
            Keys.onEscapePressed: root.close()
        }
    }
}
