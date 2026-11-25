/* Enclave OS — installer slideshow (slideshowAPI 2), Enclave Ember.
 * Shown above the install progress bar while Enclave copies itself to disk:
 * four quiet slides about what's waiting, each with a small illustration of
 * Enclave's own pieces, and page dots. */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    readonly property color ember: "#FF7A1A"
    readonly property color text: "#F5F3EF"
    readonly property color muted: "#A7A39B"
    readonly property color card: "#1A1C21"
    readonly property color line: "#2C2F36"

    function onActivate() { advance.running = true }
    function onLeave() { advance.running = false }

    Rectangle { anchors.fill: parent; color: "#101114"; z: -100 }

    Timer {
        id: advance
        interval: 7000
        repeat: true
        running: true
        onTriggered: presentation.goToNextSlide()
    }

    // one slide: eyebrow, title, body on the left; art on the right
    component Page: Slide {
        id: pg
        property string eyebrow
        property string heading
        property string body
        default property alias art: artBox.data
        // fill the whole canvas (Calamares' base slide sits inset)
        x: 0; y: 0
        width: presentation.width; height: presentation.height

        Rectangle {
            anchors.fill: parent
            color: "#101114"
            Rectangle {   // ember warmth from the lower right
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.45; color: "#00101114" }
                    GradientStop { position: 1.0; color: "#1AFF7A1A" }
                }
            }
        }
        Column {
            anchors.left: parent.left; anchors.leftMargin: parent.width * 0.07
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.42
            spacing: 12
            Text { text: pg.eyebrow; color: presentation.ember; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
            Text { width: parent.width; text: pg.heading; wrapMode: Text.WordWrap; color: presentation.text; font.family: "Inter"; font.pixelSize: 30; font.weight: Font.DemiBold }
            Text { width: parent.width; text: pg.body; wrapMode: Text.WordWrap; color: presentation.muted; font.family: "Inter"; font.pixelSize: 15; lineHeight: 1.35 }
        }
        Item {
            id: artBox
            anchors.right: parent.right; anchors.rightMargin: parent.width * 0.07
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.38; height: parent.height * 0.62
        }
    }

    component Tile: Rectangle {
        property color tint: presentation.ember
        width: 44; height: 44; radius: 13
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(tint, 1.18) }
            GradientStop { position: 1; color: tint }
        }
    }

    Page {
        eyebrow: "INSTALLING ENCLAVE OS"
        heading: "A calm desktop of its own"
        body: "The dock, the Now widget and search are waiting the moment you sign in. Pinned apps keep their windows under one icon."
        // a floating dock
        Rectangle {
            anchors.centerIn: parent
            width: 300; height: 76; radius: 24
            color: presentation.card; border.color: presentation.line
            Row {
                anchors.centerIn: parent; spacing: 12
                Repeater {
                    model: ["#FF7A1A", "#FFAC55", "#3B82F6", "#22A06B", "#8B5CF6"]
                    Tile { tint: modelData }
                }
            }
            Rectangle { x: 34; y: 66; width: 14; height: 3; radius: 2; color: presentation.ember }
        }
    }

    Page {
        eyebrow: "ENCLAVE SETTINGS"
        heading: "Everything in one place"
        body: "Network, displays, sound, power and the Activity monitor live together in Enclave Settings, in light or dark."
        Rectangle {
            anchors.centerIn: parent
            width: 300; height: 190; radius: 18
            color: presentation.card; border.color: presentation.line
            Rectangle { x: 0; y: 0; width: 92; height: parent.height; radius: 18; color: "#16181C" }
            Column {
                x: 12; y: 18; spacing: 9
                Repeater {
                    model: 5
                    Rectangle { width: 68; height: 18; radius: 6; color: index === 1 ? "#2A1D14" : "transparent"
                        Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: index === 1 ? 40 : 34; height: 5; radius: 3; color: index === 1 ? presentation.ember : "#3A3D45" } }
                }
            }
            Column {
                x: 110; y: 22; spacing: 12
                Repeater {
                    model: 3
                    Rectangle {
                        width: 172; height: 40; radius: 10; color: "#202329"
                        Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 6; radius: 3; color: "#4A4D55" }
                        Rectangle { // switch
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 18; radius: 9; color: index !== 2 ? presentation.ember : "#3A3D45"
                            Rectangle { width: 14; height: 14; radius: 7; y: 2; x: index !== 2 ? 16 : 2; color: "#FFFFFF" }
                        }
                    }
                }
            }
        }
    }

    Page {
        eyebrow: "YOUR APPS"
        heading: "Runs what you use"
        body: "Linux apps from Flathub, and Windows (Wine/Proton) and Android (Waydroid) apps when you opt in. Third-party apps keep their own icons."
        Grid {
            anchors.centerIn: parent
            columns: 3; spacing: 16
            Repeater {
                model: ["#FF7A1A", "#3B82F6", "#22A06B", "#FFAC55", "#8B5CF6", "#E95B16"]
                Tile { width: 64; height: 64; radius: 18; tint: modelData }
            }
        }
    }

    Page {
        eyebrow: "PRIVATE BY DESIGN"
        heading: "Yours, not watched"
        body: "No tracking. The assistant helps and advises, but it never operates your computer on its own."
        Item {
            anchors.centerIn: parent
            width: 170; height: 170
            Rectangle { anchors.centerIn: parent; width: 170; height: 170; radius: 85; color: "transparent"; border.color: "#2C2F36"; border.width: 2 }
            Rectangle { anchors.centerIn: parent; width: 120; height: 120; radius: 60; color: "#1A1C21"; border.color: "#4A2C17"; border.width: 2 }
            Rectangle { // lock
                anchors.centerIn: parent; anchors.verticalCenterOffset: 8
                width: 46; height: 36; radius: 9; color: presentation.ember
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 7; height: 12; radius: 3; color: "#2A1D14" }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -16
                width: 32; height: 30; radius: 16; color: "transparent"; border.color: presentation.ember; border.width: 5
            }
        }
    }

    // page dots
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        spacing: 8
        z: 10
        Repeater {
            model: presentation.slides.length
            Rectangle {
                width: index === presentation.currentSlide ? 22 : 7; height: 7; radius: 4
                color: index === presentation.currentSlide ? presentation.ember : "#3A3D45"
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }
}
