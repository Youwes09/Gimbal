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
    NumberAnimation {
        id: showAnim
        target: root; property: "t"; to: 1
        duration: 260; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "t"; to: 0; duration: 160; easing.type: Easing.InCubic }
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
        color: Qt.alpha(Theme.bg, 0.62 * root.t)
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

        Keys.onPressed: (e) => {
            const k = e.key
            const p = Status.player
            if (k === Qt.Key_Escape) Sh.closeDeck()
            else if (k === Qt.Key_Tab) DeckUi.cycle(1)
            else if (k === Qt.Key_Backtab) DeckUi.cycle(-1)
            else if (k >= Qt.Key_1 && k <= Qt.Key_4) {
                DeckUi.section = ["home", "notifications", "captures", "session"][k - Qt.Key_1]
                DeckUi.zone = "center"
            }
            else if (k === Qt.Key_Space) { if (p && p.canTogglePlaying) p.togglePlaying() }
            else if (k === Qt.Key_BracketLeft) { if (p && p.canGoPrevious) p.previous() }
            else if (k === Qt.Key_BracketRight) { if (p && p.canGoNext) p.next() }
            else if (k === Qt.Key_W) Sh.walls()
            else if (k === Qt.Key_S) Capture.shot("region")
            else if (k === Qt.Key_R) { if (!Capture.recording) Sh.closeDeck(); Capture.recToggle() }
            else if (k === Qt.Key_D) Notifications.toggleDnd()
            else if (k === Qt.Key_M) Audio.toggleMute()
            else if (k === Qt.Key_L) Sh.rest()
            else DeckUi.nav(k, e.modifiers)
            e.accepted = true
        }
    }
}
