import QtQuick
import QtQuick.Effects
import "root:/modules"

// Rest screen: no password, any key or click returns. Shown on idle and Super+L.
Item {
    id: root
    anchors.fill: parent

    readonly property color fg:    Qt.rgba(1, 1, 1, 0.96)
    readonly property color muted: Qt.rgba(1, 1, 1, 0.5)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.24)

    // OLED: nudge everything a few pixels each minute so nothing sits on the same pixels for long.
    property real driftX: 0
    property real driftY: 0
    Connections {
        target: Status
        function onNowChanged() {
            root.driftX = Math.round((Math.random() * 2 - 1) * Sh.fs(14))
            root.driftY = Math.round((Math.random() * 2 - 1) * Sh.fs(10))
        }
    }

    Column {
        id: col
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY - Sh.fs(20)
        spacing: Sh.fs(6)
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 2400; easing.type: Easing.InOutSine } }
        Behavior on anchors.verticalCenterOffset   { NumberAnimation { duration: 2400; easing.type: Easing.InOutSine } }

        // Keeps the text legible over bright patches of the blurred wallpaper.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.85)
            shadowBlur: 1.0
            blurMax: 48
        }

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            content: Status.day + "  ·  " + Status.date
            color: root.muted
            font.family: Sh.font
            font.pixelSize: Sh.fs(16)
            font.weight: Font.Medium
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Sh.fs(10)

            ScrambleText {
                id: clock
                delay: 60
                content: Status.time
                color: root.fg
                font.family: Sh.font
                font.pixelSize: Sh.fs(136)
                font.weight: Font.DemiBold
            }
            ScrambleText {
                anchors.baseline: clock.baseline
                delay: 120
                content: Status.meridiem
                color: Theme.accent
                font.family: Sh.font
                font.pixelSize: Sh.fs(22)
                font.weight: Font.Medium
                font.letterSpacing: 2
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Sh.fs(18)
            topPadding: Sh.fs(10)

            Row {
                visible: Status.hasBattery
                spacing: Sh.fs(7)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sh.batteryGlyph(Status.pct, Status.charging)
                    color: Status.charging ? Theme.accent : Status.low ? Theme.error : root.muted
                    font.family: Sh.iconFont
                    font.pixelSize: Sh.fs(17)
                }
                ScrambleText {
                    anchors.verticalCenter: parent.verticalCenter
                    delay: 160
                    content: Status.pct + "%" + (Status.batteryNote ? "   " + Status.batteryNote : "")
                    color: Status.low ? Theme.error : root.muted
                    font.family: Sh.font
                    font.pixelSize: Sh.fs(14)
                    font.letterSpacing: 1
                }
            }

            Text {
                visible: Notifications.dnd
                anchors.verticalCenter: parent.verticalCenter
                text: Sh.icBellOff
                color: Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: Sh.fs(16)
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Status.track.length > 0
            spacing: Sh.fs(8)
            topPadding: Sh.fs(4)
            opacity: Status.playing ? 1 : 0.6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.playing ? Sh.icMusic : Sh.icPause
                color: Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: Sh.fs(14)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Sh.fs(520))
                text: Status.track
                elide: Text.ElideRight
                color: root.muted
                font.family: Sh.font
                font.pixelSize: Sh.fs(13)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sh.fs(36)
        text: "any key to return"
        color: root.faint
        font.family: Sh.font
        font.pixelSize: Sh.fs(12)
        font.letterSpacing: 1
    }
}
