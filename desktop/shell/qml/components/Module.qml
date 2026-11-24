// A Control Center module: a raised tile on the glass panel.
import QtQuick
import Enclave

Rectangle {
    radius: Theme.radius.medium + 2
    color: Theme.dark ? Theme.c.elevated : Theme.c.surface
    border.width: 1
    border.color: Theme.c.border
}
