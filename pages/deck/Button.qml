import QtQuick
import "root:/modules"

// Icon and/or label button. `on` tints it with the accent (coral with `danger`);
// `selected` marks keyboard focus.
Rectangle {
    id: b
    property string glyph: ""
    property string label: ""
    property bool on: false
    property bool danger: false
    property bool selected: false
    property var sz: DeckUi.f
    property real glyphSize: b.sz(15)
    signal clicked()

    readonly property color tint: b.danger ? DeckUi.danger : DeckUi.accent
    readonly property color ink: b.on ? b.tint : DeckUi.text

    implicitWidth: row.implicitWidth + b.sz(24)
    implicitHeight: b.sz(34)
    radius: b.sz(8)
    color: b.on ? Qt.alpha(b.tint, 0.16)
         : b.selected ? DeckUi.sel
         : ma.containsMouse ? DeckUi.hover : DeckUi.well
    border.width: 1
    border.color: b.selected ? DeckUi.selRim : b.on ? Qt.alpha(b.tint, 0.35) : "transparent"
    Behavior on color { CAnim {} }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: b.sz(7)
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
            font.pixelSize: b.sz(12)
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
