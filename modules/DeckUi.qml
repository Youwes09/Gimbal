pragma Singleton

import QtQuick
import "root:/modules"

// Shared style and keyboard focus for the deck (Super+Tab).
QtObject {
    id: root

    readonly property real scale: 1.3
    function f(px) { return Sh.fs(px * root.scale) }

    // Raycast's system: an achromatic near-black stack, edges instead of shadows (a hairline
    // ring plus a faint inset highlight along the top, the "key"), neutral fills for anything
    // selected or on, and one accent (the wallpaper's), rationed to focus, active and on states.
    // The neutrals are fixed; only the accent follows the wallpaper.
    readonly property color canvas:   "#040506"
    readonly property color card:     "#07080a"
    readonly property color recessed: "#111214"
    readonly property color graphite: "#1b1c1e"
    readonly property color text:     "#ffffff"
    readonly property color dim:      "#9c9c9d"   // ash: secondary text
    readonly property color faint:    "#6a6b6c"   // smoke: muted labels
    readonly property color accent:   Theme.accent
    readonly property color danger:   "#ff6363"
    // Glyphs sitting on an accent fill: dark on a light accent, white on a deep one.
    readonly property color accentInk: 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.6 ? canvas : "#ffffff"
    readonly property color good:     "#59d499"

    readonly property color rim:      Qt.rgba(1, 1, 1, 0.09)    // card edge
    readonly property color sheen:    Qt.rgba(1, 1, 1, 0.09)    // inset top highlight
    readonly property color well:     Qt.rgba(1, 1, 1, 0.04)    // recessed blocks inside cards
    readonly property color line:     Qt.rgba(1, 1, 1, 0.07)
    readonly property color sel:      Qt.rgba(1, 1, 1, 0.085)
    readonly property color selRim:   Qt.alpha(accent, 0.6)
    readonly property color focusRim: Qt.alpha(accent, 0.3)     // whole card with keyboard focus
    readonly property color hover:    Qt.rgba(1, 1, 1, 0.045)

    readonly property int radius:      f(16)
    readonly property int innerRadius: f(8)
    readonly property int badgeRadius: f(6)

    // One face everywhere: the shell's own Adwaita Mono. `sans`/`mono` stay as names so a
    // surface can still mark what is body text and what is metadata.
    readonly property string sans: Sh.font
    readonly property string mono: Sh.font

    // Keyboard focus. Arrows move spatially; when a zone runs out of room in a direction it
    // hands focus on with go(). Left to right: media | rail | center | quick, mixer under quick.
    property string zone: "center"
    property string section: "home"     // center panel: home | notifications | captures | session
    readonly property var sections: ["home", "notifications", "captures", "session"]
    readonly property var _next: ({
        media:  { right: "rail" },
        rail:   { left: "media", right: "center" },
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
