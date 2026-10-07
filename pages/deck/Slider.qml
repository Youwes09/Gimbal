import QtQuick
import "root:/modules"

// Labelled level control. Drag or click; with keyboard focus ←/→ nudge it (handled by the owner).
Item {
    id: sl
    property string label: ""
    property string glyph: ""
    property real value: 0
    property bool muted: false
    property bool selected: false
    signal moved(real v)
    signal glyphClicked()

    implicitHeight: DeckUi.f(46)

    Rectangle {
        anchors.fill: parent
        anchors.margins: -DeckUi.f(6)
        radius: DeckUi.innerRadius
        color: sl.selected ? DeckUi.sel : "transparent"
        border.width: 1
        border.color: sl.selected ? DeckUi.selRim : "transparent"
    }

    Text {
        id: icon
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -DeckUi.f(3)
        width: DeckUi.f(20)
        text: sl.glyph
        color: sl.muted ? Theme.error : Theme.fg
        font.family: Sh.iconFont
        font.pixelSize: DeckUi.f(15)
        MouseArea { anchors.fill: parent; anchors.margins: -DeckUi.f(6); onClicked: sl.glyphClicked() }
    }
    Text {
        anchors.left: track.left
        anchors.top: parent.top
        width: track.width - pct.width
        text: sl.label
        elide: Text.ElideRight
        color: DeckUi.dim
        font.family: Sh.font
        font.pixelSize: DeckUi.f(11.5)
    }
    Text {
        id: pct
        anchors.right: parent.right
        anchors.top: parent.top
        text: sl.muted ? "muted" : Math.round(sl.value * 100) + "%"
        color: sl.muted ? Theme.error : DeckUi.faint
        font.family: Sh.font
        font.pixelSize: DeckUi.f(11)
    }
    Item {
        id: track
        anchors.left: icon.right
        anchors.right: parent.right
        anchors.leftMargin: DeckUi.f(8)
        anchors.verticalCenter: icon.verticalCenter
        height: DeckUi.f(5)

        Rectangle { anchors.fill: parent; radius: height / 2; color: DeckUi.line }
        Rectangle {
            width: Math.max(height, track.width * Math.max(0, Math.min(1, sl.value)))
            height: parent.height
            radius: height / 2
            color: sl.muted ? DeckUi.faint : Theme.accent
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 120 } }
        }
        Rectangle {
            width: DeckUi.f(13); height: width; radius: width / 2
            x: track.width * Math.max(0, Math.min(1, sl.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            opacity: ma.containsMouse || ma.pressed || sl.selected ? 1 : 0
            scale: ma.pressed ? 1.15 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -DeckUi.f(10)
            hoverEnabled: true
            preventStealing: true
            function at(x) { return Math.max(0, Math.min(1, (x - DeckUi.f(10)) / track.width)) }
            onPressed: (m) => sl.moved(at(m.x))
            onPositionChanged: (m) => { if (pressed) sl.moved(at(m.x)) }
        }
    }
}
