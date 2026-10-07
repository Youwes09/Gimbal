import QtQuick
import Quickshell
import "root:/modules"

// Month grid with the selected day's events beside it. Arrows move the day (and hand off at the
// grid's edges), PgUp/PgDn flip months, T jumps to today, Enter opens the day in Google Calendar.
Item {
    id: cal

    property date sel: new Date()
    property date view: new Date(sel.getFullYear(), sel.getMonth(), 1)
    onSelChanged: if (sel.getMonth() !== view.getMonth() || sel.getFullYear() !== view.getFullYear())
                      view = new Date(sel.getFullYear(), sel.getMonth(), 1)

    readonly property int fdow: Qt.locale().firstDayOfWeek % 7
    readonly property var cells: {
        const first = cal.view
        const lead = (first.getDay() - cal.fdow + 7) % 7
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i))
        return out
    }
    readonly property int selIndex: {
        const t = Calendar.dayStart(cal.sel)
        return cal.cells.findIndex(d => d.getTime() === t)
    }
    // Event colours per day in view, for the dots.
    readonly property var marks: {
        const m = {}
        const a = cal.cells[0].getTime(), b = cal.cells[41].getTime() + 86400000
        for (const e of Calendar.events) {
            const s = Math.max(e.start, a), end = Math.min(Math.max(e.end, e.start + 1), b)
            for (const d = new Date(s); Calendar.dayStart(d) < end; d.setDate(d.getDate() + 1)) {
                const k = Calendar.dayStart(d)
                ;(m[k] = m[k] || []).push(e.color)
            }
        }
        return m
    }
    readonly property var dayEvents: { const _ = Calendar.events; return Calendar.on(cal.sel) }

    function shift(days) { cal.sel = new Date(cal.sel.getFullYear(), cal.sel.getMonth(), cal.sel.getDate() + days) }
    function month(n) {
        const d = new Date(cal.sel.getFullYear(), cal.sel.getMonth() + n, 1)
        const dim = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        cal.sel = new Date(d.getFullYear(), d.getMonth(), Math.min(cal.sel.getDate(), dim))
    }
    function google(path) {
        Sh.closeDeck()
        Qt.openUrlExternally("https://calendar.google.com/calendar/r/" + path)
    }
    function openDay(d) { cal.google("day/" + d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate()) }
    function time(t) { return Qt.formatTime(new Date(t), "h:mm AP") }

    // ── keyboard: the grid, with the header buttons above it ────────────
    property bool atBar: false
    property int btn: 0
    readonly property var bar: [
        () => cal.month(-1), () => { cal.sel = new Date() }, () => cal.month(1),
        () => cal.google("month/" + cal.view.getFullYear() + "/" + (cal.view.getMonth() + 1) + "/1")
    ]
    readonly property bool kb: DeckUi.zone === "center"
    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "calendar") return
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            if (key === Qt.Key_PageUp)   { cal.month(-1); return }
            if (key === Qt.Key_PageDown) { cal.month(1); return }
            if (key === Qt.Key_T)        { cal.sel = new Date(); return }
            if (cal.atBar) {
                if (key === Qt.Key_Left)  { if (cal.btn === 0) DeckUi.go("left"); else cal.btn-- }
                if (key === Qt.Key_Right) { if (cal.btn === cal.bar.length - 1) DeckUi.go("right"); else cal.btn++ }
                if (key === Qt.Key_Down)  cal.atBar = false
                if (enter) cal.bar[cal.btn]()
                return
            }
            const col = cal.selIndex % 7
            if (key === Qt.Key_Left)  { if (col === 0) DeckUi.go("left"); else cal.shift(-1) }
            if (key === Qt.Key_Right) { if (col === 6) DeckUi.go("right"); else cal.shift(1) }
            if (key === Qt.Key_Up)    { if (cal.selIndex < 7) cal.atBar = true; else cal.shift(-7) }
            if (key === Qt.Key_Down)  cal.shift(7)
            if (enter) cal.openDay(cal.sel)
        }
    }

    // ── header ──────────────────────────────────────────────────────────
    Column {
        id: header
        anchors.left: parent.left
        spacing: DeckUi.f(4)
        Text {
            text: Qt.formatDate(cal.view, "MMMM yyyy")
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(24)
            font.weight: Font.DemiBold
        }
        Text {
            text: !Calendar.configured ? "Not connected"
                : Calendar.loading ? "Syncing…"
                : Calendar.error.length ? Calendar.error
                : (() => { const n = Calendar.on(new Date()).length
                           return n === 0 ? "Nothing today" : n + (n === 1 ? " event today" : " events today") })()
            color: Calendar.error.length ? Theme.error : DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
        }
    }
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: DeckUi.f(8)
        Button { glyph: Sh.icChevronLeft; selected: cal.kb && cal.atBar && cal.btn === 0; onClicked: cal.bar[0]() }
        Button { label: "Today"; selected: cal.kb && cal.atBar && cal.btn === 1; onClicked: cal.bar[1]() }
        Button { glyph: Sh.icChevronRight; selected: cal.kb && cal.atBar && cal.btn === 2; onClicked: cal.bar[2]() }
        Button { glyph: Sh.icExternal; label: "Google"; selected: cal.kb && cal.atBar && cal.btn === 3; onClicked: cal.bar[3]() }
    }

    // ── month grid ──────────────────────────────────────────────────────
    Item {
        id: gridBox
        anchors { left: parent.left; top: header.bottom; bottom: parent.bottom; topMargin: DeckUi.f(22) }
        width: parent.width * 0.56

        Row {
            id: weekdays
            width: parent.width
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: weekdays.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((cal.fdow + index) % 7, Locale.ShortFormat).slice(0, 2)
                    color: DeckUi.faint
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(10.5)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                }
            }
        }

        Grid {
            id: grid
            anchors { left: parent.left; right: parent.right; top: weekdays.bottom; bottom: parent.bottom; topMargin: DeckUi.f(10) }
            columns: 7
            readonly property real cw: width / 7
            readonly property real ch: height / 6

            Repeater {
                model: cal.cells
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool inMonth: modelData.getMonth() === cal.view.getMonth()
                    readonly property bool today: modelData.getTime() === Calendar.dayStart(Status.now)
                    readonly property bool picked: index === cal.selIndex
                    readonly property var dots: cal.marks[modelData.getTime()] || []
                    width: grid.cw
                    height: grid.ch

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: DeckUi.f(2)
                        radius: DeckUi.innerRadius
                        color: cell.picked ? DeckUi.sel : cellMa.containsMouse ? DeckUi.hover : "transparent"
                        border.width: 1
                        border.color: cell.picked && cal.kb && !cal.atBar ? DeckUi.selRim : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Rectangle {
                        id: num
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: (parent.height - height) / 2 - DeckUi.f(5)
                        width: DeckUi.f(26); height: width
                        radius: width / 2
                        color: cell.today ? Theme.accent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.today ? Theme.bg : cell.inMonth ? Theme.fg : DeckUi.faint
                            font.family: Sh.font
                            font.pixelSize: DeckUi.f(12.5)
                            font.weight: cell.today || cell.picked ? Font.Bold : Font.Normal
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: num.bottom
                        anchors.topMargin: DeckUi.f(3)
                        spacing: DeckUi.f(3)
                        Repeater {
                            model: cell.dots.slice(0, 3)
                            Rectangle {
                                required property var modelData
                                width: DeckUi.f(4); height: width; radius: width / 2
                                color: modelData
                                opacity: cell.inMonth ? 1 : 0.4
                            }
                        }
                    }
                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { cal.atBar = false; cal.sel = cell.modelData }
                        onDoubleClicked: cal.openDay(cell.modelData)
                    }
                }
            }
        }
    }

    // ── the selected day ────────────────────────────────────────────────
    Item {
        anchors { left: gridBox.right; leftMargin: DeckUi.f(24); right: parent.right; top: gridBox.top; bottom: parent.bottom }

        Caption {
            id: dayCap
            anchors { left: parent.left; right: parent.right; top: parent.top }
            text: Qt.formatDate(cal.sel, "dddd, MMMM d")
            trailing: cal.dayEvents.length ? cal.dayEvents.length + (cal.dayEvents.length === 1 ? " event" : " events") : ""
        }

        Flickable {
            anchors { left: parent.left; right: parent.right; top: dayCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(12) }
            contentHeight: agenda.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: Calendar.configured

            Column {
                id: agenda
                width: parent.width
                spacing: DeckUi.f(8)

                Repeater {
                    model: cal.dayEvents
                    Rectangle {
                        id: ev
                        required property var modelData
                        readonly property bool past: !modelData.allDay && modelData.end < Status.now.getTime()
                        width: agenda.width
                        height: evCol.implicitHeight + DeckUi.f(20)
                        radius: DeckUi.innerRadius
                        color: evMa.containsMouse ? DeckUi.hover : DeckUi.well
                        opacity: ev.past ? 0.55 : 1

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: DeckUi.f(10) }
                            width: DeckUi.f(3)
                            radius: width / 2
                            color: ev.modelData.color
                        }
                        Column {
                            id: evCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            anchors.leftMargin: DeckUi.f(22)
                            anchors.rightMargin: DeckUi.f(12)
                            spacing: DeckUi.f(3)
                            Text {
                                text: ev.modelData.allDay ? "All day"
                                    : cal.time(ev.modelData.start) + " – " + cal.time(ev.modelData.end)
                                color: DeckUi.dim
                                font.family: Sh.font
                                font.pixelSize: DeckUi.f(10.5)
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: ev.modelData.title
                                color: Theme.fg
                                font.family: Sh.font
                                font.pixelSize: DeckUi.f(13)
                                font.weight: Font.DemiBold
                            }
                            Row {
                                visible: ev.modelData.meet.length > 0 || ev.modelData.location.length > 0
                                width: parent.width
                                spacing: DeckUi.f(6)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ev.modelData.meet.length ? Sh.icVideo : Sh.icMapPin
                                    color: DeckUi.faint
                                    font.family: Sh.iconFont
                                    font.pixelSize: DeckUi.f(11)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - DeckUi.f(20)
                                    elide: Text.ElideRight
                                    text: ev.modelData.meet.length ? "Google Meet" : ev.modelData.location
                                    color: DeckUi.faint
                                    font.family: Sh.font
                                    font.pixelSize: DeckUi.f(10.5)
                                }
                            }
                        }
                        MouseArea {
                            id: evMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (ev.modelData.meet.length) { Sh.closeDeck(); Qt.openUrlExternally(ev.modelData.meet) }
                                else cal.openDay(cal.sel)
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: Calendar.configured && cal.dayEvents.length === 0
            spacing: DeckUi.f(8)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Sh.icCalendar
                color: DeckUi.faint
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(24)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing scheduled"
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: DeckUi.f(12.5)
            }
        }

        // Not connected yet: how to.
        Column {
            anchors { left: parent.left; right: parent.right; top: dayCap.bottom; topMargin: DeckUi.f(18) }
            visible: !Calendar.configured
            spacing: DeckUi.f(10)
            Text {
                text: "Connect Google Calendar"
                color: Theme.fg
                font.family: Sh.font
                font.pixelSize: DeckUi.f(13.5)
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                text: "In Google Calendar open Settings, pick your calendar, and copy "
                    + "“Secret address in iCal format”. Put it on its own line in "
                    + "~/.config/gimbal/calendars — add more lines for more calendars, "
                    + "optionally as “Work | address”."
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: DeckUi.f(11.5)
            }
        }
    }
}
