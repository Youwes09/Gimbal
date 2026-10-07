import QtQuick
import Quickshell
import "root:/modules"

// One list row, Raycast style: an icon in a uniform container, title over a quieter subtitle,
// metadata on the right in mono. Nothing drawn at rest; hover lifts it, selection adds the
// accent ring.
Rectangle {
    id: row
    property string icon: ""          // image path / theme icon; falls back to `glyph`
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string meta: ""
    property string badge: ""         // short accent figure, e.g. "+19"
    property bool selected: false
    property bool dimmed: false
    signal clicked()

    implicitHeight: DeckUi.f(52)
    radius: DeckUi.innerRadius
    color: row.selected ? DeckUi.sel : ma.containsMouse ? DeckUi.hover : "transparent"
    border.width: 1
    border.color: row.selected ? DeckUi.selRim : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    // Icon container: every icon sits on the same 32px tile, whatever its own shape.
    Rectangle {
        id: tile
        anchors.left: parent.left
        anchors.leftMargin: DeckUi.f(10)
        anchors.verticalCenter: parent.verticalCenter
        width: DeckUi.f(32); height: width
        radius: DeckUi.f(8)
        color: DeckUi.graphite
        border.width: 1
        border.color: DeckUi.line

        AppIcon {
            anchors.centerIn: parent
            visible: row.icon.length > 0
            width: DeckUi.f(20); height: width
            icon: row.icon
            fallbackGlyph: row.glyph || Sh.icApp
        }
        Text {
            anchors.centerIn: parent
            visible: row.icon.length === 0
            text: row.glyph
            color: DeckUi.dim
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(14)
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: DeckUi.f(12)
        anchors.right: side.left
        anchors.rightMargin: DeckUi.f(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(2)
        opacity: row.dimmed ? 0.6 : 1
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: row.title
            color: DeckUi.text
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(13)
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: text.length > 0
            elide: Text.ElideRight
            text: row.subtitle
            color: DeckUi.dim
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(11.5)
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: DeckUi.f(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(8)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.badge.length > 0
            text: row.badge
            color: DeckUi.accent
            font.family: DeckUi.mono
            font.pixelSize: DeckUi.f(10.5)
            font.weight: Font.Medium
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
