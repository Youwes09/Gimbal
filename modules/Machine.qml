pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Hardware toggles for the deck's quick tiles: the ASUS power profile and keyboard backlight
// (asusctl) and WayOLED's time-of-day colour temperature (oledctl). Read when the deck
// opens; each tile reads "Unavailable" when its tool isn't there.
QtObject {
    id: root

    // Power profile
    readonly property var profiles: ["Quiet", "Balanced", "Performance"]
    property string profile: ""          // "" until read, or when asusctl is missing
    readonly property bool hasProfile: root.profile.length > 0

    function nextProfile() {
        if (!root.hasProfile) return
        const i = root.profiles.indexOf(root.profile)
        const next = root.profiles[(i + 1) % root.profiles.length]
        root.profile = next               // optimistic; the read-back below confirms
        _setProfile.command = ["asusctl", "profile", "set", next]
        _setProfile.running = true
    }

    property Process _getProfile: Process {
        command: ["asusctl", "profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /Active profile:\s*(\w+)/.exec(this.text)
                root.profile = m ? m[1] : ""
            }
        }
    }
    property Process _setProfile: Process {
        onExited: root._getProfile.running = true
    }

    // Colour temperature
    property bool warmth: false
    property int kelvin: 0
    property bool hasWarmth: false

    function toggleWarmth() {
        if (!root.hasWarmth) return
        root.warmth = !root.warmth
        _setWarmth.command = ["oledctl", "colortemp", root.warmth ? "on" : "off"]
        _setWarmth.running = true
    }

    property Process _getWarmth: Process {
        command: ["oledctl", "colortemp", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text
                root.hasWarmth = /enabled=/.test(t)
                root.warmth = /enabled=1/.test(t)
                const k = /kelvin=(\d+)/.exec(t)
                root.kelvin = k ? parseInt(k[1]) : 0
            }
        }
    }
    property Process _setWarmth: Process {
        onExited: root._getWarmth.running = true
    }

    // Keyboard backlight. The colour follows the wallpaper accent.
    readonly property var kbdLevels: ["Off", "Low", "Med", "High"]
    property string kbd: ""              // one of kbdLevels; "" until read or without asusctl
    readonly property bool hasKbd: root.kbd.length > 0

    function nextKbd() {
        if (!root.hasKbd) return
        const i = root.kbdLevels.indexOf(root.kbd)
        root.kbd = root.kbdLevels[(i + 1) % root.kbdLevels.length]   // optimistic; read back below
        _setKbd.command = ["asusctl", "leds", "set", root.kbd.toLowerCase()]
        _setKbd.running = true
    }

    property Process _getKbd: Process {
        command: ["asusctl", "leds", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /brightness:\s*(\w+)/.exec(this.text)
                root.kbd = m ? m[1] : ""
            }
        }
    }
    property Process _setKbd: Process {
        onExited: root._getKbd.running = true
    }

    // LEDs wash pale colours out to white, so the hue goes at full brightness with some
    // saturation; a near-grey accent stays white.
    readonly property color kbdColour: {
        const a = Theme.accent
        return a.hsvSaturation < 0.12 ? "#ffffff" : Qt.hsva(a.hsvHue, Math.max(0.65, a.hsvSaturation), 1, 1)
    }
    onKbdColourChanged: _kbdSync.restart()
    // Setting an effect also switches the backlight on, so put the brightness back after.
    property Timer _kbdSync: Timer {
        interval: 600
        onTriggered: {
            root._setColour.command = ["sh", "-c",
                'l=$(asusctl leds get | sed "s/.*: //" | tr A-Z a-z); '
                + 'asusctl aura effect static -c "$1" && [ -n "$l" ] && asusctl leds set "$l"',
                "_", root.kbdColour.toString().slice(1)]
            root._setColour.running = true
        }
    }
    property Process _setColour: Process {
        onExited: root._getKbd.running = true
    }

    function refresh() {
        _getProfile.running = true
        _getWarmth.running = true
        _getKbd.running = true
    }
    property Connections _deck: Connections {
        target: Sh
        function onDeckShownChanged() { if (Sh.deckShown) root.refresh() }
    }
    Component.onCompleted: { refresh(); _kbdSync.restart() }
}
