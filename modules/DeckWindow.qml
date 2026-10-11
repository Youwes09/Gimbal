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
            hideAnim.stop()
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

    // One still of the screen per open, blurred; bleeds past the edges so they stay soft. The
    // blur runs once: its result is kept as a texture and the effect stops drawing, since
    // the whole window repaints on every animation frame and a live full-screen blur made
    // every animation in the deck expensive.
    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: Item {
            opacity: shot.hasContent ? root.t : 0
            ScreencopyView {
                id: shot
                anchors.fill: parent
                anchors.margins: -96
                captureSource: root.screen
                live: false
                visible: false
                onHasContentChanged: if (hasContent) bake.start()
            }
            // Blur and dim, baked together into `still`.
            Item {
                id: backdrop
                anchors.fill: shot
                MultiEffect {
                    anchors.fill: parent
                    source: shot
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    blurMultiplier: 1.6
                    saturation: -0.2
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(DeckUi.canvas, 0.62)
                }
            }
            ShaderEffectSource {
                id: still
                anchors.fill: shot
                sourceItem: backdrop
                live: false
                visible: false
            }
            // Two frames for the capture and its blur to land, then freeze them.
            Timer {
                id: bake
                interval: 80
                onTriggered: { still.scheduleUpdate(); still.hideSource = true; still.visible = true }
            }
        }
    }
    MouseArea { anchors.fill: parent; enabled: root.active; onClicked: Sh.closeDeck() }

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
