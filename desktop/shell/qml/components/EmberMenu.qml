// Ember context menu: rounded card, soft hover; opens as its own popup so it
// can leave the surface it belongs to (dock, Start, Control Center).
import QtQuick
import QtQuick.Controls
import Enclave

Menu {
    popupType: Popup.Window
    padding: 6
    palette.window: Theme.dark ? Theme.c.elevated : Theme.c.surface
    palette.windowText: Theme.c.text
    palette.text: Theme.c.text
    palette.buttonText: Theme.c.text
    palette.brightText: Theme.c.text
    palette.highlightedText: Theme.c.text
    palette.midlight: Theme.c.hover
    palette.highlight: Theme.c.accentSoft
    palette.light: Theme.c.hover
    palette.mid: Theme.c.border
    palette.dark: Theme.c.border
    background: Rectangle {
        implicitWidth: 220
        radius: Theme.radius.medium
        color: Theme.dark ? Theme.c.elevated : Theme.c.surface
        border.width: 1
        border.color: Theme.c.border
    }
}
