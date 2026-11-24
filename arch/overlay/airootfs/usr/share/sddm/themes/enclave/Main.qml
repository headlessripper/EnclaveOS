// Enclave OS — SDDM login theme.
// Clean and Windows-familiar: a calm full-screen background, a centred clock,
// and a single sign-in card (avatar, name, password). No external QML modules
// beyond Qt Quick, so it renders on a minimal greeter session.
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.backgroundFill !== "" ? config.backgroundFill : "#0E1621"

    // Enclave accent, with a safe default.
    property color accent: config.accentColor !== "" ? config.accentColor : "#ff6b1a"
    property color ink:    config.textColor   !== "" ? config.textColor   : "#F3F5F8"

    // --- background: painted gradient (always works) + optional image on top ---
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0B1220" }
            GradientStop { position: 0.55; color: "#101B2B" }
            GradientStop { position: 1.0; color: "#0A1018" }
        }
    }
    Image {
        id: bg
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // If the file is missing/unsupported, we simply keep the gradient.
        onStatusChanged: if (status === Image.Error) visible = false
    }
    // Subtle darkening for text legibility.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.28
    }

    // --- centred clock (Windows lock-screen vibe) ---
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        spacing: 2

        Text {
            id: clock
            Layout.alignment: Qt.AlignHCenter
            color: root.ink
            font.pixelSize: 86
            font.weight: Font.Light
            text: Qt.formatTime(new Date(), "HH:mm")
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.78)
            font.pixelSize: 20
            font.weight: Font.Normal
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                clock.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }
    }

    // --- sign-in card ---
    Column {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.08
        spacing: 16
        width: 320

        // Circular avatar with the Enclave mark.
        Rectangle {
            width: 108; height: 108
            radius: 54
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            Image {
                anchors.centerIn: parent
                width: 60; height: 60
                source: "/usr/share/enclave/enclave-logo-dark.svg"
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                onStatusChanged: if (status === Image.Error) visible = false
            }
        }

        // User selector (shows the name; a dropdown only when >1 account).
        ComboBox {
            id: userBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            model: userModel
            textRole: "name"
            currentIndex: userModel.lastIndex
            flat: true
            enabled: userModel.count > 1
            contentItem: Text {
                text: userBox.displayText
                color: root.ink
                font.pixelSize: 22
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Item {}
            indicator: Item {}
        }

        // Password field with an inline sign-in arrow.
        Rectangle {
            id: pwWrap
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 46
            radius: config.cornerRadius !== "" ? parseInt(config.cornerRadius) : 10
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            border.color: password.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.22)

            TextField {
                id: password
                anchors.left: parent.left
                anchors.right: goBtn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                echoMode: TextInput.Password
                passwordCharacter: "●"
                placeholderText: "Password"
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.55)
                color: root.ink
                font.pixelSize: 15
                background: Item {}
                focus: true
                onAccepted: doLogin()
                Keys.onEscapePressed: text = ""
            }

            // Sign-in arrow button.
            Rectangle {
                id: goBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 5
                width: 38; height: 38
                radius: 8
                color: goArea.containsMouse ? Qt.lighter(root.accent, 1.08) : root.accent
                Text {
                    anchors.centerIn: parent
                    text: "→"       // →
                    color: "#1A1008"
                    font.pixelSize: 20
                    font.bold: true
                }
                MouseArea {
                    id: goArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }
        }

        // Error / status line.
        Text {
            id: statusLine
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#FF8A7A"
            font.pixelSize: 13
            text: ""
            opacity: text !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // --- bottom-left: session + keyboard (quiet, not a big top bar) ---
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 14

        ComboBox {
            id: sessionBox
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            width: 220
            contentItem: Text {
                leftPadding: 10
                text: "Session: " + sessionBox.displayText
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: 8
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }
        }
    }

    // --- bottom-right: power controls ---
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 10

        // Restart
        Rectangle {
            width: 42; height: 42; radius: 21
            color: rebootArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Text { anchors.centerIn: parent; text: "↻"; color: root.ink; font.pixelSize: 17 }
            MouseArea {
                id: rebootArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }

        // Shut down
        Rectangle {
            width: 42; height: 42; radius: 21
            color: offArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Text { anchors.centerIn: parent; text: "⏻"; color: root.ink; font.pixelSize: 17 }
            MouseArea {
                id: offArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }

    // --- login plumbing ---
    function doLogin() {
        statusLine.text = ""
        sddm.login(userBox.currentText, password.text, sessionBox.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { statusLine.text = "" }
        function onLoginFailed() {
            statusLine.text = "Incorrect password. Try again."
            password.text = ""
            password.forceActiveFocus()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
