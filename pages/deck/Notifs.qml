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

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "notifications") return
            if (key === Qt.Key_Up)   nt.cur = Math.max(0, nt.cur - 1)
            if (key === Qt.Key_Down) nt.cur = Math.min(nt.count - 1, nt.cur + 1)
            if (key === Qt.Key_Return || key === Qt.Key_Enter) nt.open(nt.cur)
            if (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X) nt.drop(nt.cur)
            if (key === Qt.Key_C) Notifications.clearAll()
        }
    }

    Column {
        id: header
        anchors.left: parent.left
        spacing: DeckUi.f(4)
        Text {
            text: "Notifications"
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(24)
            font.weight: Font.DemiBold
        }
        Text {
            text: nt.count === 0 ? "Nothing new" : nt.count + (nt.count === 1 ? " notification" : " notifications")
                  + (Notifications.dnd ? "  ·  Focus is on, popups are silenced" : "")
            color: DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
        }
    }
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: DeckUi.f(8)
        Button {
            glyph: Notifications.dnd ? Sh.icBellOff : Sh.icBell
            label: "Focus"
            on: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
        Button {
            visible: nt.count > 0
            glyph: Sh.icTrash
            label: "Clear all"
            onClicked: Notifications.clearAll()
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(20)
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
            selected: DeckUi.zone === "center" && nt.cur === index
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
            font.family: Sh.font
            font.pixelSize: DeckUi.f(13)
        }
    }
}
