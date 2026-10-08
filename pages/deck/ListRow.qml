import QtQuick
import Quickshell
import "root:/modules"

// One list row, Raycast style: a bare icon, the title with a quieter subtitle on the same
// line, accessories on the right. Nothing drawn at rest; hover and selection fill it.
Rectangle {
    id: row
    property string icon: ""          // image path / theme icon; falls back to `glyph`
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string meta: ""
    property string badge: ""         // short accent tag, e.g. "+19"
    property bool selected: false
    signal clicked()

    implicitHeight: DeckUi.f(40)
    radius: DeckUi.innerRadius
    color: row.selected ? DeckUi.sel : ma.containsMouse ? DeckUi.hover : "transparent"
    border.width: 1
    border.color: row.selected ? DeckUi.selRim : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Item {
        id: ic
        anchors.left: parent.left
        anchors.leftMargin: DeckUi.f(10)
        anchors.verticalCenter: parent.verticalCenter
        width: DeckUi.f(20); height: width

        AppIcon {
            anchors.fill: parent
            visible: row.icon.length > 0
            icon: row.icon
            fallbackGlyph: row.glyph || Sh.icApp
            fallbackColor: DeckUi.dim
        }
        Text {
            anchors.centerIn: parent
            visible: row.icon.length === 0
            text: row.glyph
            color: DeckUi.dim
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(15)
        }
    }

    Item {
        id: body
        anchors.left: ic.right
        anchors.leftMargin: DeckUi.f(12)
        anchors.right: side.left
        anchors.rightMargin: DeckUi.f(12)
        anchors.verticalCenter: parent.verticalCenter
        height: title.implicitHeight

        Text {
            id: title
            width: Math.min(implicitWidth, body.width)
            elide: Text.ElideRight
            text: row.title
            color: DeckUi.text
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12.5)
            font.weight: Font.Medium
        }
        Text {
            anchors.left: title.right
            anchors.leftMargin: DeckUi.f(10)
            anchors.right: parent.right
            anchors.baseline: title.baseline
            visible: row.subtitle.length > 0 && width > DeckUi.f(24)
            elide: Text.ElideRight
            text: row.subtitle
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(11.5)
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: DeckUi.f(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(10)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.badge.length > 0
            width: tag.implicitWidth + DeckUi.f(10)
            height: tag.implicitHeight + DeckUi.f(4)
            radius: DeckUi.badgeRadius
            color: Qt.alpha(DeckUi.accent, 0.14)
            Text {
                id: tag
                anchors.centerIn: parent
                text: row.badge
                color: DeckUi.accent
                font.family: DeckUi.mono
                font.pixelSize: DeckUi.f(10.5)
                font.weight: Font.Medium
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.meta.length > 0
            text: row.meta
            color: DeckUi.faint
            font.family: DeckUi.mono
            font.pixelSize: DeckUi.f(10.5)
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
