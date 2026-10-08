import QtQuick
import "root:/modules"

// Full notification history. ↑↓ move · enter open · del dismiss · c clear all.
Item {
    id: nt

    readonly property int count: Notifications.historyModel.count
    property int cur: 0
    onCountChanged: cur = Math.max(0, Math.min(cur, count - 1))

    function open(i) {
        if (i < 0 || i >= nt.count) return
        const r = Notifications.historyModel.get(i)
        Sh.closeDeck()
        Notifications.focusSender(r)
        Notifications.invoke(r.nid, "")
        Notifications.dismiss(r.nid)
    }
    function drop(i) {
        if (i >= 0 && i < nt.count) Notifications.dismiss(Notifications.historyModel.get(i).nid)
    }

    // Keyboard: the list, with the header buttons above it (atBar; btn 0 Focus, 1 Clear all).
    property bool atBar: false
    property int btn: 0
    readonly property bool kb: DeckUi.zone === "center"
    readonly property bool barKb: kb && (atBar || count === 0)
    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "notifications") return
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            if (nt.atBar || nt.count === 0) {
                const last = nt.count > 0 ? 1 : 0
                nt.btn = Math.min(nt.btn, last)
                if (key === Qt.Key_Left)  { if (nt.btn === 0) DeckUi.go("left"); else nt.btn-- }
                if (key === Qt.Key_Right) { if (nt.btn === last) DeckUi.go("right"); else nt.btn++ }
                if (key === Qt.Key_Down && nt.count > 0) nt.atBar = false
                if (enter) { if (nt.btn === 0) Notifications.toggleDnd(); else Notifications.clearAll() }
                return
            }
            if (key === Qt.Key_Left)  DeckUi.go("left")
            if (key === Qt.Key_Right) DeckUi.go("right")
            if (key === Qt.Key_Up)    { if (nt.cur === 0) nt.atBar = true; else nt.cur-- }
            if (key === Qt.Key_Down)  nt.cur = Math.min(nt.count - 1, nt.cur + 1)
            if (enter) nt.open(nt.cur)
            if (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X) nt.drop(nt.cur)
            if (key === Qt.Key_C) Notifications.clearAll()
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "Notifications"
        detail: (nt.count > 0 ? String(nt.count) : "") + (Notifications.dnd ? (nt.count > 0 ? "  ·  " : "") + "Popups silenced" : "")
        Button {
            glyph: Notifications.dnd ? Sh.icBellOff : Sh.icBell
            label: "Focus"
            on: Notifications.dnd
            selected: nt.barKb && nt.btn === 0
            onClicked: Notifications.toggleDnd()
        }
        Button {
            visible: nt.count > 0
            glyph: Sh.icTrash
            label: "Clear all"
            selected: nt.barKb && nt.btn === 1
            onClicked: Notifications.clearAll()
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(14)
        model: Notifications.historyModel
        spacing: DeckUi.f(8)
        clip: true
        currentIndex: nt.cur
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: NotifRow {
            required property int index
            required property var model
            width: list.width
            rec: model
            selected: nt.kb && !nt.atBar && nt.cur === index
            onClicked: nt.open(index)
        }
        displaced: Transition { NumberAnimation { property: "y"; duration: 160; easing.type: Easing.OutCubic } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140 } }
    }

    Column {
        anchors.centerIn: list
        visible: nt.count === 0
        spacing: DeckUi.f(8)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Sh.icSparkles
            color: DeckUi.faint
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(28)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "All caught up"
            color: DeckUi.dim
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(13)
        }
    }
}
