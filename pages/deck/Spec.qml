import QtQuick
import "root:/modules"

// One spec-sheet line: a faint label on the left, its value in mono on the right.
Item {
    id: spec
    property string label
    property string value
    property color valueColor: DeckUi.dim

    implicitHeight: DeckUi.f(18)
    width: parent ? parent.width : 0
    height: implicitHeight

    Text {
        id: lbl
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: spec.label
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(11.5)
    }
    Text {
        anchors { left: lbl.right; leftMargin: DeckUi.f(12); right: parent.right; verticalCenter: parent.verticalCenter }
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: spec.value || "—"
        color: spec.value ? spec.valueColor : DeckUi.faint
        font.family: DeckUi.mono
        font.pixelSize: DeckUi.f(11.5)
    }
}
