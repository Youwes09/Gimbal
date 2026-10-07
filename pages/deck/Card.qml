import QtQuick
import QtQuick.Effects
import "root:/modules"

// Deck surface: lit from above (lifted top, hairline rim, bright lip along the top edge) with
// its own soft shadow. The shadow is analytic, so nothing is rendered offscreen. The rim
// takes the accent when the card has keyboard focus.
Rectangle {
    id: card
    property bool focused: false

    radius: DeckUi.radius
    border.width: 1
    border.color: card.focused ? DeckUi.focusRim : DeckUi.rim
    Behavior on border.color { ColorAnimation { duration: 180 } }
    gradient: Gradient {
        GradientStop { position: 0.0; color: DeckUi.cardTop }
        GradientStop { position: 0.35; color: DeckUi.card }
        GradientStop { position: 1.0; color: DeckUi.card }
    }

    RectangularShadow {
        anchors.fill: parent
        z: -1
        radius: card.radius
        blur: DeckUi.f(30)
        offset.y: DeckUi.f(12)
        spread: -DeckUi.f(4)
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: card.radius }
        anchors.topMargin: 1
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: DeckUi.sheen }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
