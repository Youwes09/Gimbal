import QtQuick
import "root:/modules"

// Icon (+ label) button. `on` tints it, `selected` shows keyboard focus.
Rectangle {
    id: b
    property string glyph: ""
    property string label: ""
    property bool on: false
    property bool selected: false
    property color tint: Theme.accent
    property real glyphSize: DeckUi.f(15)
    signal clicked()

    implicitWidth: row.implicitWidth + DeckUi.f(24)
    implicitHeight: DeckUi.f(36)
    radius: DeckUi.innerRadius
    color: b.on ? Qt.alpha(b.tint, 0.16)
         : b.selected ? DeckUi.sel
         : ma.containsMouse ? DeckUi.hover : DeckUi.well
    border.width: 1
    border.color: b.selected ? DeckUi.selRim : b.on ? Qt.alpha(b.tint, 0.4) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: DeckUi.f(7)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.glyph.length > 0
            text: b.glyph
            color: b.on ? b.tint : Theme.fg
            font.family: Sh.iconFont
            font.pixelSize: b.glyphSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.label.length > 0
            text: b.label
            color: b.on ? b.tint : Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
            font.weight: Font.Medium
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
