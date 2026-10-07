import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"
import "root:/pages"

PanelWindow {
    id: root
    readonly property bool open: Sh.launcherShown === true

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-launcher"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: root.open ? null : idleRegion
    Region { id: idleRegion }

    property bool active: false
    property real t: 0

    onOpenChanged: {
        if (root.open) { root.active = true; showAnim.restart() }
        else hideAnim.restart()
    }
    NumberAnimation {
        id: showAnim
        target: root; property: "t"; to: 1
        duration: 130; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "t"; to: 0; duration: 110; easing.type: Easing.InCubic }
        ScriptAction { script: root.active = false }
    }

    // Dashboard only: frosted backdrop, one still of the screen per open, freed on close.
    Loader {
        anchors.fill: parent
        active: root.active && Sh.dash
        sourceComponent: Item {
            // Bleed past the screen edges, where the blur would otherwise thin out.
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
                    saturation: -0.25
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.active
        color: Qt.alpha(Theme.bg, (Sh.dash ? 0.74 : 0.2) * root.t)
        MouseArea { anchors.fill: parent; onClicked: Sh.closeLauncher() }
    }

    // Below the launcher so its results drop over the cards; steps back while searching.
    Dashboard {
        anchors.fill: parent
        visible: root.active && Sh.dash && opacity > 0.01
        panel: launcher.panel
        t: root.t
        property real fade: launcher.searching ? 0 : 1
        Behavior on fade { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        opacity: root.t * fade
        enabled: !launcher.searching
    }

    LauncherPage {
        id: launcher
        anchors.fill: parent
        visible: root.active
        opacity: root.t
        transformOrigin: Item.Center
        scale: 0.985 + 0.015 * root.t
        transform: Translate { y: (1 - root.t) * 10 }
    }
}
