import QtQuick
import "root:/modules"

// Page toolbar, Raycast style: the title with a short status beside it, the page's actions on
// the right, and a hairline across the panel underneath. Children become the actions.
Item {
    id: ph
    property string title: ""
    property string detail: ""
    property color detailTint: DeckUi.faint
    default property alias actions: bar.data

    readonly property real barH: DeckUi.f(34)
    implicitHeight: ph.barH + DeckUi.f(15)
    height: implicitHeight

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.verticalCenter: bar.verticalCenter
        text: ph.title
        color: DeckUi.text
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(15)
        font.weight: Font.DemiBold
    }
    Text {
        anchors.left: titleText.right
        anchors.leftMargin: DeckUi.f(10)
        anchors.right: bar.left
        anchors.rightMargin: DeckUi.f(12)
        anchors.baseline: titleText.baseline
        visible: ph.detail.length > 0
        elide: Text.ElideRight
        text: ph.detail
        color: ph.detailTint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(12)
    }
    Row {
        id: bar
        anchors.right: parent.right
        y: 0
        height: ph.barH
        spacing: DeckUi.f(6)
    }

    // Runs edge to edge: from the rail divider to the card's right edge (the body's margins).
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -DeckUi.f(24)
        anchors.rightMargin: -DeckUi.f(24)
        height: 1
        color: DeckUi.line
    }
}
