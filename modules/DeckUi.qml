pragma Singleton

import QtQuick
import "root:/modules"

// Shared style and keyboard focus for the deck (Super+Tab).
QtObject {
    id: root

    readonly property real scale: 1.12
    function f(px) { return Sh.fs(px * root.scale) }

    // Same surface language as the launcher, so the two read as one shell.
    readonly property color card:    Qt.tint(Theme.surface, Qt.rgba(1, 1, 1, 0.035))
    readonly property color rim:     Qt.alpha(Theme.fg, 0.11)
    readonly property color sheen:   Qt.alpha(Theme.fg, 0.07)
    readonly property color well:    Qt.alpha(Theme.fg, 0.045)   // inset blocks inside cards
    readonly property color line:    Qt.alpha(Theme.fg, 0.08)
    readonly property color dim:     Qt.alpha(Theme.fg, 0.56)
    readonly property color faint:   Qt.alpha(Theme.fg, 0.3)
    readonly property color sel:     Qt.alpha(Theme.accent, 0.14)
    readonly property color selRim:  Qt.alpha(Theme.accent, 0.55)
    readonly property color hover:   Qt.alpha(Theme.fg, 0.06)

    readonly property int radius:      f(14)
    readonly property int innerRadius: f(10)

    // Keyboard zones, cycled with Tab. Arrows / Enter / Delete go to the active one via nav().
    readonly property var zones: ["center", "sound", "quick", "media"]
    property string zone: "center"
    property string section: "home"     // center panel: home | notifications | captures | session

    signal nav(int key, int modifiers)

    function cycle(dir) {
        const i = root.zones.indexOf(root.zone)
        root.zone = root.zones[(i + dir + root.zones.length) % root.zones.length]
    }
    function reset() {
        root.zone = "center"
        root.section = "home"
    }

    // Keeps Gimbal's own idle rest screen away (Stay awake tile).
    property bool stayAwake: false
}
