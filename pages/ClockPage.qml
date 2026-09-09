import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    readonly property color fg:     Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted:  Qt.rgba(1, 1, 1, 0.5)
    readonly property color accent: Qt.rgba(0.56, 0.9, 0.66, 0.95)

    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property int  h24: now.getHours()
    readonly property int  h12: (h24 % 12) === 0 ? 12 : h24 % 12
    readonly property int  mins: now.getMinutes()
    readonly property string hh: (h12  < 10 ? "0" : "") + h12
    readonly property string mm: (mins < 10 ? "0" : "") + mins

    readonly property var days:   ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var months: ["January","February","March","April","May","June",
                                   "July","August","September","October","November","December"]

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    readonly property int  batteryPct: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Sh.fs(8)

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            content: root.days[root.now.getDay()] + ", "
                     + root.months[root.now.getMonth()] + " " + root.now.getDate()
            color: root.muted
            font.family: Sh.font
            font.pixelSize: Sh.fs(17)
            font.weight: Font.Medium
            font.letterSpacing: 3
            font.capitalization: Font.AllUppercase
        }

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 60
            content: root.hh + ":" + root.mm
            color: root.fg
            font.family: Sh.font
            font.pixelSize: Sh.fs(128)
            font.weight: Font.DemiBold
            font.letterSpacing: 0
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Sh.fs(16)
            topPadding: Sh.fs(4)

            Row {
                id: batSeg
                visible: root.hasBattery
                spacing: Sh.fs(5)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sh.batteryGlyph(root.batteryPct, root.charging)
                    color: root.charging ? root.accent
                           : root.batteryPct <= 20 ? Qt.rgba(1, 0.5, 0.5, 0.9)
                           : root.muted
                    font.family: Sh.iconFont
                    font.pixelSize: Sh.fs(17)
                }
                ScrambleText {
                    anchors.verticalCenter: parent.verticalCenter
                    delay: 150
                    content: root.batteryPct + "%"
                    color: root.batteryPct <= 20 && !root.charging
                           ? Qt.rgba(1, 0.5, 0.5, 0.9) : root.muted
                    font.family: Sh.font
                    font.pixelSize: Sh.fs(14)
                    font.weight: Font.Medium
                    font.letterSpacing: 1
                }
            }

            Text {
                visible: batSeg.visible && wxSeg.visible
                anchors.verticalCenter: parent.verticalCenter
                text: "|"
                color: root.muted
                font.family: Sh.font
                font.pixelSize: Sh.fs(14)
            }

            Row {
                id: wxSeg
                visible: Weather.ok
                spacing: Sh.fs(8)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    readonly property string glyph: Weather.glyphFor(Weather.text)
                    visible: glyph.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: glyph
                    color: root.muted
                    font.family: Sh.iconFont
                    font.pixelSize: Sh.fs(16)
                }
                ScrambleText {
                    anchors.verticalCenter: parent.verticalCenter
                    delay: 220
                    content: Weather.text
                    color: root.muted
                    font.family: Sh.font
                    font.pixelSize: Sh.fs(14)
                    font.letterSpacing: 1
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        text: "esc to close"
        color: Qt.rgba(1, 1, 1, 0.22)
        font.family: Sh.font
        font.pixelSize: Sh.fs(12)
        opacity: Sh.powerZone === "bottom" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
