import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Session actions. Reboot, shut down and log out ask for a second press.
Item {
    id: ses

    readonly property var actions: [
        { id: "rest",     glyph: Sh.icLock,    label: "Rest",      hint: "Clock screen, any key returns" },
        { id: "suspend",  glyph: Sh.icMoon,    label: "Suspend",   hint: "Sleep until you open the lid" },
        { id: "logout",   glyph: Sh.icLogOut,  label: "Log out",   hint: "End the mango session",  confirm: true },
        { id: "reboot",   glyph: Sh.icRotate,  label: "Reboot",    hint: "Restart the machine",    confirm: true },
        { id: "poweroff", glyph: Sh.icPower,   label: "Shut down", hint: "Power off",              confirm: true }
    ]
    property int cur: 0
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: ses.armed = "" }

    function act(a) {
        if (a.confirm && ses.armed !== a.id) { ses.armed = a.id; disarm.restart(); return }
        ses.armed = ""
        if (a.id === "rest") { Sh.rest(); return }
        Sh.closeDeck()
        if (a.id === "suspend")  Quickshell.execDetached(["systemctl", "suspend"])
        if (a.id === "logout")   Quickshell.execDetached(["mmsg", "dispatch", "quit"])
        if (a.id === "reboot")   Quickshell.execDetached(["systemctl", "reboot"])
        if (a.id === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "session") return
            if (key === Qt.Key_Left) {
                if (ses.cur === 0) DeckUi.go("left")
                else { ses.cur--; ses.armed = "" }
            }
            if (key === Qt.Key_Right) {
                if (ses.cur === ses.actions.length - 1) DeckUi.go("right")
                else { ses.cur++; ses.armed = "" }
            }
            if (key === Qt.Key_Return || key === Qt.Key_Enter) ses.act(ses.actions[ses.cur])
        }
    }

    property string uptime: ""
    property string host: ""
    property Process _up: Process {
        running: Sh.deckShown
        command: ["cat", "/proc/uptime", "/proc/sys/kernel/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ln = this.text.split("\n")
                ses.host = (ln[1] || "").trim()
                const s = Math.floor(parseFloat(ln[0]) || 0)
                const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
                ses.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m"
            }
        }
    }

    Column {
        id: header
        anchors.left: parent.left
        spacing: DeckUi.f(4)
        Text {
            text: "Session"
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(24)
            font.weight: Font.DemiBold
        }
        Text {
            text: "Up " + ses.uptime + "  ·  " + Quickshell.env("USER") + " on " + ses.host
            color: DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.verticalCenterOffset: DeckUi.f(10)
        spacing: DeckUi.f(14)
        readonly property real w: Math.min(DeckUi.f(118), (ses.width - spacing * 4) / 5)

        Repeater {
            model: ses.actions
            Rectangle {
                id: ab
                required property var modelData
                required property int index
                readonly property bool sel: DeckUi.zone === "center" && ses.cur === index
                readonly property bool arm: ses.armed === modelData.id
                width: row.w
                height: row.w * 1.1
                radius: DeckUi.radius
                color: ab.arm ? Qt.alpha(Theme.error, 0.16) : ab.sel ? DeckUi.sel : abMa.containsMouse ? DeckUi.hover : DeckUi.well
                border.width: 1
                border.color: ab.arm ? Qt.alpha(Theme.error, 0.6) : ab.sel ? DeckUi.selRim : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -DeckUi.f(10)
                    text: ab.modelData.glyph
                    color: ab.arm ? Theme.error : ab.sel ? Theme.accent : Theme.fg
                    font.family: Sh.iconFont
                    font.pixelSize: DeckUi.f(26)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: DeckUi.f(16)
                    text: ab.arm ? "Again to confirm" : ab.modelData.label
                    color: ab.arm ? Theme.error : Theme.fg
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(ab.arm ? 10.5 : 12.5)
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: abMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ses.cur = ab.index
                    onClicked: ses.act(ab.modelData)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: row.bottom
        anchors.topMargin: DeckUi.f(18)
        text: ses.actions[ses.cur].hint
        color: DeckUi.faint
        font.family: Sh.font
        font.pixelSize: DeckUi.f(11.5)
    }
}
