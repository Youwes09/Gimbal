import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    function f(px) { return Sh.fs(px) }

    readonly property color fg:     Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted:  Qt.rgba(1, 1, 1, 0.5)
    readonly property color faint:  Qt.rgba(1, 1, 1, 0.26)
    readonly property color accent: Qt.rgba(0.56, 0.9, 0.66, 0.95)

    readonly property var _bat: UPower.displayDevice
    readonly property bool hasBattery: _bat && _bat.isLaptopBattery
    function _pct() { return root.hasBattery ? Math.round(root._bat.percentage * 100) : -1 }

    property bool resumed: false
    property bool armed: false
    property double _last: Date.now()
    property double welcomeAt: 0
    property int startPct: -1
    property int endPct: -1
    property double elapsedMs: 0

    Timer { id: armDelay; interval: 1500; onTriggered: root.armed = true }

    function tryDismiss() { if (root.armed) Sh.close() }

    Component.onCompleted: {
        root.startPct = root._pct()
        Sh.suspendBattery = root.startPct
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const now = Date.now()
            const gap = now - root._last
            root._last = now
            if (!root.resumed) {
                if (gap > 5000) {
                    root.resumed = true
                    root.elapsedMs = now - Sh.suspendAt
                    root.endPct = root._pct()
                    root.welcomeAt = now
                    armDelay.start()
                } else if (now - Sh.suspendAt > 90000) {
                    Sh.close()
                }
            } else if (now - root.welcomeAt > 7000) {
                Sh.close()
            }
        }
    }

    function _dur(ms) {
        const s = Math.max(0, Math.round(ms / 1000))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (h > 0) return h + "h " + (m < 10 ? "0" : "") + m + "m"
        if (m > 0) return m + "m"
        return s + "s"
    }

    property date now: new Date()
    Timer {
        interval: 1000; running: root.resumed; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.resumed ? 0.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.centerIn: parent
        opacity: root.resumed ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 300 } }
        text: Sh.icMoon
        color: root.faint
        font.family: Sh.iconFont
        font.pixelSize: root.f(56)
        SequentialAnimation on scale {
            running: !root.resumed; loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.06; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.06; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
        }
    }

    Column {
        id: back
        anchors.centerIn: parent
        spacing: root.f(10)
        opacity: root.resumed ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        scale: root.resumed ? 1 : 0.96
        Behavior on scale {
            NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            gateOnReveal: false
            show: root.resumed
            content: "WELCOME BACK"
            color: root.muted
            font.family: Sh.font
            font.pixelSize: root.f(16)
            font.weight: Font.Medium
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 80
            gateOnReveal: false
            show: root.resumed
            content: {
                const h24 = root.now.getHours()
                const h = (h24 % 12) === 0 ? 12 : h24 % 12
                const m = root.now.getMinutes()
                return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
            }
            color: root.fg
            font.family: Sh.font
            font.pixelSize: root.f(96)
            font.weight: Font.DemiBold
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.f(14)
            topPadding: root.f(6)

            ScrambleText {
                anchors.verticalCenter: parent.verticalCenter
                delay: 170
                gateOnReveal: false
                show: root.resumed
                content: "asleep " + root._dur(root.elapsedMs)
                color: root.muted
                font.family: Sh.font
                font.pixelSize: root.f(14)
                font.letterSpacing: 1
            }
            Text {
                visible: dropTxt.visible
                anchors.verticalCenter: parent.verticalCenter
                text: "|"
                color: root.faint
                font.family: Sh.font
                font.pixelSize: root.f(14)
            }
            ScrambleText {
                id: dropTxt
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasBattery && root.startPct >= 0 && root.endPct >= 0
                delay: 230
                gateOnReveal: false
                show: root.resumed
                content: {
                    const d = root.startPct - root.endPct
                    const s = d > 0 ? ("−" + d + "%") : d < 0 ? ("+" + (-d) + "%") : "±0%"
                    return "battery " + s + "  ·  " + root.endPct + "%"
                }
                color: root.muted
                font.family: Sh.font
                font.pixelSize: root.f(14)
                font.letterSpacing: 1
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        visible: root.resumed
        text: "any key to dismiss"
        color: Qt.rgba(1, 1, 1, 0.22)
        font.family: Sh.font
        font.pixelSize: root.f(12)
    }
}
