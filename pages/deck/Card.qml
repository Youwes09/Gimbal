import QtQuick
import QtQuick.Effects
import "root:/modules"

// Deck card: near-black fill, hairline rim, top highlight. RectangularShadow is analytic,
// so nothing renders offscreen.
Rectangle {
    id: card
    property bool focused: false

    radius: DeckUi.radius
    color: DeckUi.card
    border.width: 1
    border.color: card.focused ? DeckUi.focusRim : DeckUi.rim
    Behavior on border.color { CAnim {} }

    RectangularShadow {
        anchors.fill: parent
        z: -1
        radius: card.radius
        blur: DeckUi.f(40)
        offset.y: DeckUi.f(4)
        spread: DeckUi.f(2)
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: card.radius * 0.6 }
        anchors.topMargin: 1
        height: 1
        color: DeckUi.sheen
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: card.radius * 0.6 }
        anchors.bottomMargin: 1
        height: 1
        color: Qt.rgba(0, 0, 0, 0.35)
    }
}
