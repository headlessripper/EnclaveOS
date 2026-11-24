/* Enclave OS — installer slideshow (slideshowAPI 2). */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function onActivate() { presentation.startTimer(); }
    function onLeave()    { presentation.stopTimer(); }

    Timer {
        id: advanceTimer
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0E1621"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome to Enclave OS"
                    color: "#F3F5F8"; font.pixelSize: 30; font.weight: Font.Light
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "A clean, Windows-familiar desktop on a fast Arch base."
                    color: "#B9C2CF"; font.pixelSize: 16
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0E1621"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Runs your apps"
                    color: "#FF7A3D"; font.pixelSize: 26
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Linux, Windows (Wine/Proton) and Android (Waydroid) — opt in anytime."
                    color: "#B9C2CF"; font.pixelSize: 16
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0E1621"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Yours, not watched"
                    color: "#FF7A3D"; font.pixelSize: 26
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "The assistant helps and advises — it never operates your machine."
                    color: "#B9C2CF"; font.pixelSize: 16
                }
            }
        }
    }
}
