pragma Singleton

import QtQuick
import "root:/modules"

// Shared style and keyboard focus for the deck (Super+Tab).
QtObject {
    id: root

    readonly property real scale: 1.3
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

    // Keyboard focus. Arrows move spatially; when a zone runs out of room in a direction it
    // hands focus on with go(). Left to right: media | rail | center | quick, mixer under quick.
    property string zone: "center"
    property string section: "home"     // center panel: home | notifications | captures | calendar | session
    readonly property var sections: ["home", "notifications", "captures", "calendar", "session"]
    readonly property var _next: ({
        clock:  { right: "rail", down: "media" },
        media:  { right: "rail", up: "clock" },
        rail:   { left: "clock", right: "center" },
        center: { left: "rail", right: "quick" },
        quick:  { left: "center", down: "mixer" },
        mixer:  { up: "quick" }
    })

    signal nav(int key, int modifiers)

    // Deferred so the zone being entered doesn't also act on the key that got it there.
    function go(dir) {
        const z = (root._next[root.zone] || {})[dir]
        if (z && !(z === "media" && !Status.player)) Qt.callLater(() => root.zone = z)
    }
    function page(dir) {
        const i = root.sections.indexOf(root.section)
        root.section = root.sections[(i + dir + root.sections.length) % root.sections.length]
        root.zone = "center"
    }
    function reset() {
        root.zone = "center"
        root.section = "home"
    }

    // Keeps Gimbal's own idle rest screen away (Stay awake tile).
    property bool stayAwake: false
}
