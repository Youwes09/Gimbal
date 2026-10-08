import QtQuick
import "root:/modules"

// Level control: icon (click to mute), label and value, then the bar. The owner handles keys.
Item {
    id: sl
    property string label: ""
    property string glyph: ""
    property string icon: ""            // app icon path; shown instead of `glyph` when set
    property real value: 0
    property bool muted: false
    property bool selected: false
    property bool mutable: true
    signal moved(real v)
    signal glyphClicked()

    implicitHeight: DeckUi.f(48)

    Rectangle {
        anchors.fill: parent
        anchors.margins: -DeckUi.f(6)
        radius: DeckUi.innerRadius
        color: sl.selected ? DeckUi.sel : "transparent"
        border.width: 1
        border.color: sl.selected ? DeckUi.selRim : "transparent"
    }

    Rectangle {
        id: tile
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: DeckUi.f(34); height: width
        radius: DeckUi.f(8)
        color: sl.muted ? Qt.alpha(DeckUi.danger, 0.14) : tileMa.containsMouse ? DeckUi.recessed : DeckUi.graphite
        border.width: 1
        border.color: sl.muted ? Qt.alpha(DeckUi.danger, 0.35) : DeckUi.line
        Behavior on color { CAnim {} }

        AppIcon {
            anchors.centerIn: parent
            visible: sl.icon.length > 0
            width: DeckUi.f(20); height: width
            icon: sl.icon
            fallbackGlyph: sl.glyph
            opacity: sl.muted ? 0.45 : 1
        }
        Text {
            anchors.centerIn: parent
            visible: sl.icon.length === 0
            text: sl.glyph
            color: sl.muted ? DeckUi.danger : DeckUi.text
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(15)
        }
        MouseArea {
            id: tileMa
            anchors.fill: parent
            enabled: sl.mutable
            hoverEnabled: true
            cursorShape: sl.mutable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: sl.glyphClicked()
        }
    }

    Text {
        id: name
        anchors.left: tile.right
        anchors.leftMargin: DeckUi.f(12)
        anchors.right: pct.left
        anchors.rightMargin: DeckUi.f(8)
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: DeckUi.f(2)
        text: sl.label
        elide: Text.ElideRight
        color: DeckUi.text
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(12)
    }
    Text {
        id: pct
        anchors.right: parent.right
        anchors.baseline: name.baseline
        text: sl.muted ? "Muted" : Math.round(sl.value * 100) + "%"
        color: sl.muted ? DeckUi.danger : DeckUi.faint
        font.family: DeckUi.mono
        font.pixelSize: DeckUi.f(11)
    }

    Item {
        id: track
        anchors.left: name.left
        anchors.right: parent.right
        anchors.top: parent.verticalCenter
        anchors.topMargin: DeckUi.f(7)
        height: DeckUi.f(4)

        Rectangle { anchors.fill: parent; radius: height / 2; color: DeckUi.line }
        Rectangle {
            width: Math.max(height, track.width * Math.max(0, Math.min(1, sl.value)))
            height: parent.height
            radius: height / 2
            color: sl.muted ? DeckUi.faint : DeckUi.accent
            Behavior on width { enabled: !ma.pressed; Anim { duration: Motion.fast } }
        }
        Rectangle {
            width: DeckUi.f(12); height: width; radius: width / 2
            x: track.width * Math.max(0, Math.min(1, sl.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: DeckUi.text
            opacity: ma.containsMouse || ma.pressed || sl.selected ? 1 : 0
            scale: ma.pressed ? 1.15 : 1
            Behavior on opacity { Anim { duration: Motion.fast } }
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
