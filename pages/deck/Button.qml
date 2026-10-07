import QtQuick
import "root:/modules"

// Icon (+ label) button. At rest a quiet recessed well; `on` is the system's one filled
// surface (Mist with Iron text), or a warm coral wash when `danger` (recording);
// `selected` shows keyboard focus as a brighter ring.
Rectangle {
    id: b
    property string glyph: ""
    property string label: ""
    property bool on: false
    property bool danger: false
    property bool selected: false
    property real glyphSize: DeckUi.f(15)
    signal clicked()

    readonly property color ink: b.on ? (b.danger ? DeckUi.accent : DeckUi.iron) : DeckUi.text

    implicitWidth: row.implicitWidth + DeckUi.f(24)
    implicitHeight: DeckUi.f(34)
    radius: DeckUi.innerRadius
    color: b.on ? (b.danger ? "#452324" : DeckUi.mist)
         : b.selected ? DeckUi.sel
         : ma.containsMouse ? DeckUi.hover : DeckUi.well
    border.width: 1
    border.color: b.selected ? DeckUi.selRim : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: DeckUi.f(7)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.glyph.length > 0
            text: b.glyph
            color: b.ink
            font.family: Sh.iconFont
            font.pixelSize: b.glyphSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.label.length > 0
            text: b.label
            color: b.ink
            font.family: DeckUi.sans
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
