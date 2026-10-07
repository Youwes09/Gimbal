pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Hardware toggles for the deck's quick tiles: the ASUS power profile (asusctl) and
// WayOLED's time-of-day colour temperature (oledctl). Read when the deck opens; each
// tile hides itself when its tool isn't there.
QtObject {
    id: root

    // ── power profile ───────────────────────────────────────────────────
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

    // ── colour temperature ──────────────────────────────────────────────
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

    function refresh() {
        _getProfile.running = true
        _getWarmth.running = true
    }
    property Connections _deck: Connections {
        target: Sh
        function onDeckShownChanged() { if (Sh.deckShown) root.refresh() }
    }
    Component.onCompleted: refresh()
}
