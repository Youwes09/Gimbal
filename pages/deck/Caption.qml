import QtQuick
import "root:/modules"

// Section eyebrow: small uppercase mono, then a hairline fading out toward the right edge.
Item {
    id: cap
    property string text: ""
    property string trailing: ""
    property color tint: DeckUi.dim

    implicitHeight: label.implicitHeight
    height: implicitHeight

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: cap.text
        color: cap.tint
        font.family: DeckUi.mono
        font.pixelSize: DeckUi.f(10.5)
        font.weight: Font.DemiBold
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }
    Text {
        id: tail
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: cap.trailing.length > 0
        text: cap.trailing
        color: DeckUi.faint
        font.family: DeckUi.mono
        font.pixelSize: DeckUi.f(10.5)
    }
    Rectangle {
        anchors.left: label.right
        anchors.right: tail.visible ? tail.left : parent.right
        anchors.leftMargin: DeckUi.f(10)
        anchors.rightMargin: tail.visible ? DeckUi.f(10) : 0
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: DeckUi.line }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
