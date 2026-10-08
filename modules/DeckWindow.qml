import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"
import "root:/pages/deck"

// The deck (Super+Tab): frosted backdrop + three-column overview. Everything is built on open
// and torn down on close.
PanelWindow {
    id: root
    readonly property bool open: Sh.deckShown

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-deck"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: root.open ? null : idleRegion
    Region { id: idleRegion }

    property bool active: false
    property real t: 0

    onOpenChanged: {
        if (root.open) {
            DeckUi.reset()
            root.active = true
            showAnim.restart()
            keys.forceActiveFocus()
        } else hideAnim.restart()
    }
    Anim { id: showAnim; target: root; property: "t"; to: 1; duration: Motion.slow }
    SequentialAnimation {
        id: hideAnim
        AnimOut { target: root; property: "t"; to: 0 }
        ScriptAction { script: root.active = false }
    }

    // One still of the screen per open, blurred; bleeds past the edges so they stay soft.
    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: Item {
            ScreencopyView {
                anchors.fill: parent
                anchors.margins: -96
                captureSource: root.screen
                live: false
                opacity: hasContent ? root.t : 0
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    blurMultiplier: 1.6
                    saturation: -0.2
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.active
        color: Qt.alpha(DeckUi.canvas, 0.62 * root.t)
        MouseArea { anchors.fill: parent; onClicked: Sh.closeDeck() }
    }

    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: Deck { t: root.t }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Connections {
            target: DeckUi
            function onRefocus() { keys.forceActiveFocus() }
        }

        Keys.onPressed: (e) => {
            const k = e.key
            const p = Status.player
            // Arrows + Enter do everything; Tab flips pages, Space is play/pause anywhere.
            if (k === Qt.Key_Escape) Sh.closeDeck()
            else if (k === Qt.Key_Tab) DeckUi.page(1)
            else if (k === Qt.Key_Backtab) DeckUi.page(-1)
            else if (k >= Qt.Key_1 && k < Qt.Key_1 + DeckUi.sections.length) {
                DeckUi.section = DeckUi.sections[k - Qt.Key_1]
                DeckUi.zone = "center"
            }
            else if (k === Qt.Key_Space) { if (p && p.canTogglePlaying) p.togglePlaying() }
            else DeckUi.nav(k, e.modifiers)
            e.accepted = true
        }
    }
}
