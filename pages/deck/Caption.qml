import QtQuick
import "root:/modules"

// Section label with an optional note on the right.
Item {
    id: cap
    property string text: ""
    property string trailing: ""

    implicitHeight: label.implicitHeight
    height: implicitHeight

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: cap.text
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(11.5)
        font.weight: Font.Medium
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: cap.trailing.length > 0
        text: cap.trailing
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(11)
    }
}
