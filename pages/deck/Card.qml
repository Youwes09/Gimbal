import QtQuick
import "root:/modules"

// Deck surface: launcher-coloured card with a hairline rim and top sheen; the rim lights up when focused.
Rectangle {
    id: card
    property bool focused: false

    radius: DeckUi.radius
    color: DeckUi.card
    border.width: 1
    border.color: card.focused ? DeckUi.selRim : DeckUi.rim
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: DeckUi.radius }
        anchors.topMargin: 1
        height: 1
        color: DeckUi.sheen
    }
}
