import QtQuick
import "root:/modules"

// One notification, in the deck's list-row style: a bare app icon, summary over
// body, app · age in mono on the right. Nothing drawn at rest.
Rectangle {
    id: nr
    property var rec: null
    property bool selected: false
    signal clicked()

    implicitHeight: DeckUi.f(64)
    radius: DeckUi.innerRadius
    color: nr.selected ? DeckUi.sel : ma.containsMouse ? DeckUi.hover : "transparent"
    border.width: 1
    border.color: nr.selected ? DeckUi.selRim : "transparent"
    Behavior on color { CAnim {} }

    readonly property bool crit: nr.rec && nr.rec.urgency === "critical"

    Rectangle {
        visible: nr.crit
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: DeckUi.f(10) }
        width: 2
        radius: 1
        color: DeckUi.danger
    }

    Item {
        id: ic
        anchors.left: parent.left
        anchors.leftMargin: DeckUi.f(12)
        anchors.verticalCenter: parent.verticalCenter
        width: DeckUi.f(24); height: width
        AppIcon {
            anchors.fill: parent
            fallbackColor: DeckUi.dim
            icon: Notifications.iconFor(nr.rec)
            fallbackGlyph: Sh.icBell
        }
    }

    Column {
        anchors.left: ic.right
        anchors.leftMargin: DeckUi.f(12)
        anchors.right: parent.right
        anchors.rightMargin: DeckUi.f(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(2)

        Item {
            width: parent.width
            height: sum.implicitHeight
            Text {
                id: sum
                anchors.left: parent.left
                anchors.right: age.left
                anchors.rightMargin: DeckUi.f(8)
                elide: Text.ElideRight
                text: nr.rec ? Notifications.plain(nr.rec.summary) || nr.rec.app : ""
                color: DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12.5)
                font.weight: Font.DemiBold
            }
            Text {
                id: age
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: nr.rec ? nr.rec.app + "  ·  " + Status.ago(nr.rec.time) : ""
                color: DeckUi.faint
                font.family: DeckUi.mono
                font.pixelSize: DeckUi.f(10.5)
            }
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: nr.rec ? Notifications.plain(nr.rec.body) : ""
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            color: DeckUi.dim
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(11.5)
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nr.clicked()
    }
}
