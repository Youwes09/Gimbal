import QtQuick
import Quickshell
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    function f(px) { return Sh.fs(px) }

    readonly property color fg:     Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted:  Qt.rgba(1, 1, 1, 0.5)
    readonly property color faint:  Qt.rgba(1, 1, 1, 0.26)
    readonly property color accent: Theme.accent

    property bool joining: false

    Item {
        id: sheet
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: fade.start()
        NumberAnimation { id: fade; target: sheet; property: "opacity"; to: 1
            duration: 240; easing.type: Easing.OutCubic }

        Column {
            id: col
            anchors.centerIn: parent
            width: Math.min(root.f(620), root.width * 0.42)
            spacing: root.f(34)

            transform: Translate { id: rise; y: root.f(16) }
            Component.onCompleted: riseAnim.start()
            NumberAnimation { id: riseAnim; target: rise; property: "y"; to: 0
                duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

            Column {
                width: parent.width
                spacing: root.f(10)

                Item {
                    width: parent.width
                    height: root.f(38)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WI-FI"
                        color: root.faint
                        font.family: Sh.font
                        font.pixelSize: root.f(12)
                        font.letterSpacing: 2
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: root.f(16)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.joining ? Sh.icX : "+"
                            color: root.joining ? root.muted : root.accent
                            font.family: root.joining ? Sh.iconFont : Sh.font
                            font.pixelSize: root.joining ? root.f(13) : root.f(19)
                            font.weight: Font.Medium

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -root.f(8)
                                onClicked: {
                                    Network.cancelAuth()
                                    root.joining = !root.joining
                                    Sh.reclaimFocus()
                                }
                            }
                        }

                        NetToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Network.enabled
                            onToggled: Network.toggle()
                        }
                    }
                }

                JoinForm {
                    width: col.width
                    visible: root.joining
                    onSubmit: (ssid, pass) => {
                        Network.connectWithPassword(ssid, pass)
                        root.joining = false
                        Sh.reclaimFocus()
                    }
                    onCancel: {
                        root.joining = false
                        Sh.reclaimFocus()
                    }
                }

                Repeater {
                    model: Network.enabled ? Network.networks : []
                    delegate: Column {
                        id: wrap
                        required property var modelData
                        width: col.width
                        spacing: root.f(8)

                        NetRow {
                            width: wrap.width
                            title: wrap.modelData.ssid
                            glyph: Sh.icWifi
                            active: wrap.modelData.active
                            sub: (wrap.modelData.secure ? "secured · " : "open · ") + wrap.modelData.signal + "%"
                            onClicked: wrap.modelData.active
                                ? Network.disconnect(wrap.modelData.ssid)
                                : Network.connect(wrap.modelData.ssid)
                        }

                        AuthForm {
                            width: wrap.width
                            visible: Network.authTarget === wrap.modelData.ssid
                            ssid: wrap.modelData.ssid
                            error: Network.authError
                            onSubmit: (pass) => Network.connectWithPassword(wrap.modelData.ssid, pass)
                            onCancel: {
                                Network.cancelAuth()
                                Sh.reclaimFocus()
                            }
                        }
                    }
                }

                Text {
                    visible: Network.enabled && Network.networks.length === 0
                    text: Network.busy ? "scanning…" : "no networks found"
                    color: root.faint
                    font.family: Sh.font
                    font.pixelSize: root.f(13)
                    leftPadding: root.f(4)
                }
            }

            Column {
                width: parent.width
                spacing: root.f(10)

                Item {
                    width: parent.width
                    height: root.f(38)
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BLUETOOTH"
                        color: root.faint
                        font.family: Sh.font
                        font.pixelSize: root.f(12)
                        font.letterSpacing: 2
                    }
                    NetToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        checked: Bluetooth.enabled
                        onToggled: Bluetooth.toggle()
                    }
                }

                Repeater {
                    model: Bluetooth.enabled ? Bluetooth.devices : []
                    delegate: NetRow {
                        required property var modelData
                        width: col.width
                        title: modelData.name
                        glyph: Sh.icBluetooth
                        active: modelData.connected
                        sub: "paired"
                        onClicked: modelData.connected
                            ? Bluetooth.disconnectDev(modelData.mac)
                            : Bluetooth.connectDev(modelData.mac)
                    }
                }

                Text {
                    visible: Bluetooth.enabled && Bluetooth.devices.length === 0
                    text: "no paired devices"
                    color: root.faint
                    font.family: Sh.font
                    font.pixelSize: root.f(13)
                    leftPadding: root.f(4)
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            text: "esc to close"
            color: root.faint
            font.family: Sh.font
            font.pixelSize: root.f(12)
        }
    }

    component NetToggle: Item {
        id: tgl
        property bool checked: false
        signal toggled()
        width: root.f(42); height: root.f(24)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: tgl.checked ? Qt.alpha(root.accent, 0.85) : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Rectangle {
            width: root.f(18); height: root.f(18)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: tgl.checked ? parent.width - width - root.f(3) : root.f(3)
            color: "white"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; onClicked: tgl.toggled() }
    }

    component NetRow: Item {
        id: row
        property string title: ""
        property string sub: ""
        property string glyph: ""
        property bool active: false
        signal clicked()

        readonly property bool hot: tap.containsMouse
        height: root.f(56)

        Rectangle {
            id: backing
            anchors.fill: parent
            radius: root.f(16)
            color: Qt.rgba(0.07, 0.07, 0.08, row.active ? 0.82 : 0.7)
        }

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: root.f(16)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, (row.active ? 0.065 : 0.045) + (row.hot ? 0.02 : 0)) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, (row.active ? 0.05 : 0.036) + (row.hot ? 0.015 : 0)) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.028 + (row.hot ? 0.01 : 0)) }
            }
            border.width: row.active ? 1.5 : 1
            border.color: row.active ? Qt.alpha(root.accent, 0.5) : Qt.rgba(1, 1, 1, row.hot ? 0.16 : 0.1)
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.f(18)
            anchors.rightMargin: root.f(18)
            spacing: root.f(14)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.glyph
                color: row.active ? root.accent : root.muted
                font.family: Sh.iconFont
                font.pixelSize: root.f(17)
            }

            Column {
                width: parent.width - root.f(17) - parent.spacing
                    - (row.active ? statusBadge.width : 0) - (row.active ? parent.spacing : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.f(3)

                Text {
                    width: parent.width
                    text: row.title
                    color: root.fg
                    elide: Text.ElideRight
                    font.family: Sh.font
                    font.pixelSize: root.f(14)
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: row.sub
                    color: row.active ? Qt.alpha(root.accent, 0.9) : root.faint
                    elide: Text.ElideRight
                    font.family: Sh.font
                    font.pixelSize: root.f(11)
                }
            }

            Rectangle {
                id: statusBadge
                visible: row.active
                anchors.verticalCenter: parent.verticalCenter
                width: badgeText.width + root.f(16)
                height: root.f(20)
                radius: height / 2
                color: Qt.alpha(root.accent, 0.16)
                border.width: 1
                border.color: Qt.alpha(root.accent, 0.5)

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "connected"
                    color: root.accent
                    font.family: Sh.font
                    font.pixelSize: root.f(10)
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                }
            }
        }

        MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.clicked()
        }
    }

    component AuthForm: Column {
        id: form
        property string ssid: ""
        property string error: ""
        signal submit(string password)
        signal cancel()

        spacing: root.f(6)
        topPadding: root.f(2)
        bottomPadding: root.f(2)

        Rectangle {
            width: parent.width
            height: root.f(46)
            radius: root.f(14)
            color: Qt.rgba(0.07, 0.07, 0.08, 0.7)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Item {
                anchors.fill: parent
                anchors.leftMargin: root.f(16)
                anchors.rightMargin: root.f(12)

                TextInput {
                    id: pwField
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.f(28) - root.f(10)
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: root.fg
                    font.family: Sh.font
                    font.pixelSize: root.f(13)
                    selectByMouse: true
                    activeFocusOnTab: true
                    clip: true
                    cursorDelegate: Rectangle { width: 2; color: root.accent; visible: pwField.cursorVisible }
                    Keys.onReturnPressed: if (text.length > 0) form.submit(text)
                    Keys.onEnterPressed: if (text.length > 0) form.submit(text)
                    Keys.onEscapePressed: form.cancel()

                    Text {
                        visible: pwField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "password for " + form.ssid
                        color: root.muted
                        font.family: Sh.font
                        font.pixelSize: root.f(13)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sh.icX
                    color: root.muted
                    font.family: Sh.iconFont
                    font.pixelSize: root.f(13)
                    MouseArea { anchors.fill: parent; anchors.margins: -root.f(8); onClicked: form.cancel() }
                }
            }
        }

        Text {
            visible: form.error.length > 0
            width: parent.width
            text: form.error
            color: Qt.rgba(1, 0.55, 0.55, 0.9)
            font.family: Sh.font
            font.pixelSize: root.f(11)
            leftPadding: root.f(4)
            wrapMode: Text.Wrap
        }
    }

    component JoinForm: Column {
        id: jform
        signal submit(string ssid, string password)
        signal cancel()
        spacing: root.f(10)
        bottomPadding: root.f(2)

        Rectangle {
            width: parent.width
            height: root.f(46)
            radius: root.f(14)
            color: Qt.rgba(0.07, 0.07, 0.08, 0.7)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            TextInput {
                id: ssidField
                anchors.fill: parent
                anchors.leftMargin: root.f(16)
                anchors.rightMargin: root.f(16)
                verticalAlignment: TextInput.AlignVCenter
                color: root.fg
                font.family: Sh.font
                font.pixelSize: root.f(13)
                selectByMouse: true
                activeFocusOnTab: true
                clip: true
                cursorDelegate: Rectangle { width: 2; color: root.accent; visible: ssidField.cursorVisible }
                KeyNavigation.tab: jpwField
                Keys.onReturnPressed: jpwField.forceActiveFocus()
                Keys.onEscapePressed: jform.cancel()

                Text {
                    visible: ssidField.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "network name"
                    color: root.muted
                    font.family: Sh.font
                    font.pixelSize: root.f(13)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.f(46)
            radius: root.f(14)
            color: Qt.rgba(0.07, 0.07, 0.08, 0.7)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Item {
                anchors.fill: parent
                anchors.leftMargin: root.f(16)
                anchors.rightMargin: root.f(12)

                TextInput {
                    id: jpwField
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.f(34) - root.f(10)
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: root.fg
                    font.family: Sh.font
                    font.pixelSize: root.f(13)
                    selectByMouse: true
                    activeFocusOnTab: true
                    clip: true
                    cursorDelegate: Rectangle { width: 2; color: root.accent; visible: jpwField.cursorVisible }
                    Keys.onReturnPressed: if (ssidField.text.length > 0) jform.submit(ssidField.text, text)
                    Keys.onEnterPressed: if (ssidField.text.length > 0) jform.submit(ssidField.text, text)
                    Keys.onEscapePressed: jform.cancel()

                    Text {
                        visible: jpwField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "password"
                        color: root.muted
                        font.family: Sh.font
                        font.pixelSize: root.f(13)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "join"
                    color: root.accent
                    font.family: Sh.font
                    font.pixelSize: root.f(12)
                    font.weight: Font.Medium
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.f(8)
                        onClicked: if (ssidField.text.length > 0) jform.submit(ssidField.text, jpwField.text)
                    }
                }
            }
        }
    }
}
