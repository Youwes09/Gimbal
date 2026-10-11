import QtQuick
import "root:/modules"

// Month grid with today marked, then how far through the day, month and year we are.
// ‹ › page months; clicking the month name goes back to this one.
Card {
    id: cal

    property date now: new Date()
    Timer { interval: 30000; running: cal.visible; repeat: true; triggeredOnStart: true; onTriggered: cal.now = new Date() }

    property int offset: 0             // months from the current one
    onVisibleChanged: if (visible) cal.offset = 0
    readonly property date shown: new Date(cal.now.getFullYear(), cal.now.getMonth() + cal.offset, 1)

    // 42 cells from the Monday on or before the 1st.
    readonly property var cells: {
        const first = cal.shown, lead = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i)
            out.push({ day: d.getDate(), inMonth: d.getMonth() === first.getMonth(),
                       today: d.toDateString() === cal.now.toDateString(), weekend: d.getDay() % 6 === 0 })
        }
        return out
    }

    // Progress
    readonly property var marks: {
        const n = cal.now, y = n.getFullYear(), m = n.getMonth()
        const y0 = new Date(y, 0, 1), y1 = new Date(y + 1, 0, 1)
        const m0 = new Date(y, m, 1), m1 = new Date(y, m + 1, 1)
        const d0 = new Date(y, m, n.getDate())
        const doy = Math.round((d0 - y0) / 86400000) + 1, days = Math.round((y1 - y0) / 86400000)
        const left = Math.max(0, 86400000 - (n - d0)), h = Math.floor(left / 3600000), mi = Math.floor(left % 3600000 / 60000)
        // ISO week
        const t = new Date(d0); t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7)
        const w1 = new Date(t.getFullYear(), 0, 4)
        const week = 1 + Math.round(((t - w1) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7)
        return [
            { label: "Today", value: (n - d0) / 86400000, note: h + "h " + mi + "m left" },
            { label: n.toLocaleDateString(Qt.locale(), "MMMM"), value: (n - m0) / (m1 - m0),
              note: (Math.round((m1 - d0) / 86400000) - 1) + " days left" },
            { label: String(y), value: (n - y0) / (y1 - y0), note: "Day " + doy + " of " + days + "  ·  Week " + week }
        ]
    }

    component Arrow: Rectangle {
        property string glyph
        signal clicked()
        width: DeckUi.f(26); height: width
        radius: DeckUi.f(7)
        color: am.containsMouse ? DeckUi.hover : "transparent"
        Behavior on color { CAnim {} }
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: am.containsMouse ? DeckUi.text : DeckUi.dim
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(14)
        }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
        height: DeckUi.f(26)
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: cal.shown.toLocaleDateString(Qt.locale(), "MMMM") + (cal.shown.getFullYear() !== cal.now.getFullYear() ? " " + cal.shown.getFullYear() : "")
            color: DeckUi.text
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(14)
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.offset = 0 }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: DeckUi.f(2)
            Arrow { glyph: ""; onClicked: cal.offset-- }
            Arrow { glyph: ""; onClicked: cal.offset++ }
        }
    }

    Grid {
        id: grid
        anchors { left: parent.left; right: parent.right; top: head.bottom; margins: DeckUi.f(16); topMargin: DeckUi.f(12) }
        columns: 7
        readonly property real cw: width / 7
        readonly property real ch: DeckUi.f(30)

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: grid.cw
                height: DeckUi.f(22)
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: DeckUi.faint
                font.family: DeckUi.mono
                font.pixelSize: DeckUi.f(10)
            }
        }
        Repeater {
            model: cal.cells
            Item {
                required property var modelData
                width: grid.cw
                height: grid.ch
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(grid.cw, grid.ch) - DeckUi.f(2); height: width
                    radius: width / 2
                    visible: modelData.today
                    color: DeckUi.accent
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    color: modelData.today ? DeckUi.accentInk
                         : !modelData.inMonth ? Qt.alpha(DeckUi.faint, 0.45)
                         : modelData.weekend ? DeckUi.dim : DeckUi.text
                    font.family: DeckUi.mono
                    font.pixelSize: DeckUi.f(12)
                    font.weight: modelData.today ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    Rectangle {
        id: rule
        anchors { left: parent.left; right: parent.right; top: grid.bottom; topMargin: DeckUi.f(12) }
        height: 1
        color: DeckUi.line
    }

    Column {
        anchors { left: parent.left; right: parent.right; top: rule.bottom; margins: DeckUi.f(16) }
        spacing: DeckUi.f(12)
        Repeater {
            model: cal.marks
            Column {
                required property var modelData
                width: parent.width
                spacing: DeckUi.f(5)
                Item {
                    width: parent.width
                    height: lbl.implicitHeight
                    Text {
                        id: lbl
                        text: modelData.label
                        color: DeckUi.dim
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(11.5)
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors { right: parent.right; baseline: lbl.baseline }
                        text: Math.floor(modelData.value * 100) + "%"
                        color: DeckUi.text
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(11.5)
                    }
                }
                Rectangle {
                    width: parent.width
                    height: DeckUi.f(3)
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        width: parent.width * modelData.value
                        height: parent.height
                        radius: parent.radius
                        color: DeckUi.accent
                    }
                }
                Text {
                    text: modelData.note
                    color: DeckUi.faint
                    font.family: DeckUi.mono
                    font.pixelSize: DeckUi.f(10)
                }
            }
        }
    }
}
