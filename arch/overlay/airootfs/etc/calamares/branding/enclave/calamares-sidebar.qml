/* Enclave OS — installer step rail (Calamares sidebar, QML), Enclave Ember.
 *
 * The mark and "Enclave OS / Installer" on top, then the steps as a vertical
 * progress rail: finished steps get an ember check, the current one an ember
 * ring and a soft ember pill, the rest stay quiet.
 */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15
import QtQuick.Layouts 1.3

Rectangle {
    id: rail
    color: "#16181C"
    anchors.fill: parent
    implicitWidth: 168

    readonly property color ember: "#FF7A1A"
    readonly property color text: "#F5F3EF"
    readonly property color muted: "#A7A39B"
    readonly property color line: "#2C2F36"

    // hairline against the page
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#23262C" }

    // a faint ember warmth at the foot of the rail
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: parent.height * 0.45
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0016181C" }
            GradientStop { position: 1.0; color: "#1FFF7A1A" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 22
        anchors.bottomMargin: 18
        spacing: 0

        // brand
        RowLayout {
            Layout.leftMargin: 4
            spacing: 9
            Image {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                sourceSize.width: 80; sourceSize.height: 80
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Column {
                spacing: 1
                Text {
                    text: "Enclave OS"
                    color: rail.text
                    font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold
                }
                Text {
                    text: qsTr("Installer")
                    color: rail.muted
                    font.family: "Inter"; font.pixelSize: 11
                }
            }
        }

        Item { Layout.preferredHeight: 26 }

        // steps
        Repeater {
            model: ViewManager
            delegate: Item {
                id: step
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                readonly property bool current: index === ViewManager.currentStepIndex
                readonly property bool done: index < ViewManager.currentStepIndex
                readonly property bool last: index === ViewManager.rowCount() - 1

                // the rail between dots
                Rectangle {
                    visible: !step.last
                    x: 19; y: 31; width: 2; height: 22
                    radius: 1
                    color: step.done ? rail.ember : rail.line
                    opacity: step.done ? 0.7 : 1
                }

                Rectangle {   // current step pill
                    anchors.fill: parent
                    anchors.topMargin: 3; anchors.bottomMargin: 3
                    radius: 12
                    color: step.current ? "#2A1D14" : "transparent"
                    border.width: step.current ? 1 : 0
                    border.color: "#4A2C17"
                }

                Rectangle {   // dot
                    id: dot
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 10
                    color: step.done ? rail.ember : "transparent"
                    border.width: step.done ? 0 : 2
                    border.color: step.current ? rail.ember : "#3E414A"
                    Rectangle {
                        visible: step.current
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: rail.ember
                    }
                    Text {
                        visible: step.done
                        anchors.centerIn: parent
                        text: "✓"
                        color: "#FFFFFF"
                        font.pixelSize: 12; font.weight: Font.Bold
                    }
                }

                Text {
                    anchors.left: dot.right; anchors.leftMargin: 11
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: display
                    elide: Text.ElideRight
                    color: step.current ? "#FFFFFF" : (step.done ? rail.text : rail.muted)
                    font.family: "Inter"; font.pixelSize: 13
                    font.weight: step.current ? Font.DemiBold : Font.Normal
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: qsTr("Enclave installs only to the disk you choose.")
            wrapMode: Text.WordWrap
            color: "#77736D"
            font.family: "Inter"; font.pixelSize: 11
            lineHeight: 1.25
        }

    }
}
