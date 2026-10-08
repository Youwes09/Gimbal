import QtQuick
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
    Anim { id: showAnim; target: root; property: "t"; to: 1; duration: Motion.fast }
    SequentialAnimation {
        id: hideAnim
        AnimOut { target: root; property: "t"; to: 0; duration: Motion.fast }
        ScriptAction { script: root.active = false }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.active
        color: Qt.alpha(Theme.bg, 0.2 * root.t)
        MouseArea { anchors.fill: parent; onClicked: Sh.closeLauncher() }
    }

    LauncherPage {
        anchors.fill: parent
        visible: root.active
        opacity: root.t
        transformOrigin: Item.Center
        scale: 0.985 + 0.015 * root.t
        transform: Translate { y: (1 - root.t) * 10 }
    }
}
