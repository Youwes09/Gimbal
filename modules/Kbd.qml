pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Keyboard backlight. Under "auto" the first backend that works: asusctl, only with an Aura
// keyboard (which also takes the wallpaper accent); UPower's KbdBacklight, any *::kbd_backlight
// LED with no udev rule; then brightnessctl. UPower's change signals keep the level in step
// when the firmware handles the Fn keys itself.
QtObject {
    id: root

    property string backend: ""          // "" until detected, or with no backlight
    property int level: 0
    property int max: 0
    readonly property bool available: root.backend !== "" && root.max > 0
    readonly property bool aura: root.backend === "asusctl"
    readonly property real pct: root.max > 0 ? root.level / root.max : 0
    readonly property string label: !root.available ? "Unavailable"
        : root.max === 3 ? ["Off", "Low", "Medium", "High"][root.level]
        : root.level === 0 ? "Off" : Math.round(root.pct * 100) + "%"

    function set(n) {
        if (!root.available) return
        root.level = Math.max(0, Math.min(root.max, Math.round(n)))   // optimistic; read back below
        Osd.pulse("kbd")
        const l = String(root.level)
        Quickshell.execDetached(
            root.backend === "asusctl" ? ["asusctl", "leds", "set", ["off", "low", "med", "high"][root.level]]
          : root.backend === "upower"  ? root._upower("SetBrightness").concat([l])
          : ["brightnessctl", "-q", "-d", "*::kbd_backlight", "set", l])
        root._readBack.restart()
    }
    function up()    { root.set(root.level + 1) }
    function down()  { root.set(root.level - 1) }
    function cycle() { root.set((root.level + 1) % (root.max + 1)) }

    function _upower(method) {
        return ["gdbus", "call", "--system", "--dest", "org.freedesktop.UPower",
                "--object-path", "/org/freedesktop/UPower/KbdBacklight",
                "--method", "org.freedesktop.UPower.KbdBacklight." + method]
    }

    // Prints "<backend> <max> <level>" for the configured backend, or the first that works.
    function refresh() {
        root._read.command = ["sh", "-c",
            'want="$1"; try() { [ "$want" = auto ] || [ "$want" = "$1" ]; }; '
            + 'up() { gdbus call --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower/KbdBacklight '
            + '--method org.freedesktop.UPower.KbdBacklight."$1" 2>/dev/null | tr -dc 0-9; }; '
            + 'if try asusctl && command -v asusctl >/dev/null && busctl --system tree xyz.ljones.Asusd 2>/dev/null | grep -q /xyz/ljones/aura/; then '
            + '  l=$(asusctl leds get 2>/dev/null | sed "s/.*: *//"); '
            + '  case "$l" in Off) echo "asusctl 3 0";; Low) echo "asusctl 3 1";; Med) echo "asusctl 3 2";; High) echo "asusctl 3 3";; esac; '
            + 'elif try upower && m=$(up GetMaxBrightness) && [ "${m:-0}" -gt 0 ]; then echo "upower $m $(up GetBrightness)"; '
            + 'elif try brightnessctl && i=$(brightnessctl -m -d "*::kbd_backlight" info 2>/dev/null); then '
            + '  echo "brightnessctl $(echo "$i" | cut -d, -f5) $(echo "$i" | cut -d, -f3)"; fi',
            "_", Config.kbdBacklight === "none" ? "" : Config.kbdBacklight]
        root._read.running = false
        root._read.running = true
    }
    property Process _read: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(/\s+/)
                root.backend = f.length === 3 ? f[0] : ""
                root.max = parseInt(f[1]) || 0
                root.level = parseInt(f[2]) || 0
            }
        }
    }
    property Timer _readBack: Timer { interval: 400; onTriggered: root.refresh() }

    // UPower reports every change to the LED, the firmware's own ("internal") included; those
    // get the popup, since nothing else here caused them. Without gdbus there's nothing to watch.
    property Process _watch: Process {
        command: ["sh", "-c", 'command -v gdbus >/dev/null || exit 127; exec gdbus monitor --system '
            + '--dest org.freedesktop.UPower --object-path /org/freedesktop/UPower/KbdBacklight']
        running: root.available
        stdout: SplitParser {
            onRead: (line) => {
                const m = /BrightnessChangedWithSource \((\d+), '(\w+)'\)/.exec(line)
                if (!m) return
                if (root.backend === "upower") root.level = Math.min(root.max, parseInt(m[1]))
                else root._readBack.restart()
                if (m[2] === "internal") Osd.pulse("kbd")
            }
        }
        onExited: (code) => { if (code !== 127 && root.available) root._rewatch.restart() }
    }
    property Timer _rewatch: Timer { interval: 2000; onTriggered: root._watch.running = root.available }

    // LEDs wash pale colours out to white, so the hue goes at full brightness with some
    // saturation; a near-grey accent stays white.
    readonly property color colour: {
        const a = Theme.accent
        return a.hsvSaturation < 0.12 ? "#ffffff" : Qt.hsva(a.hsvHue, Math.max(0.65, a.hsvSaturation), 1, 1)
    }
    onColourChanged: if (root.aura) _colourSync.restart()
    onAuraChanged: if (root.aura) _colourSync.restart()
    // Setting an effect also switches the backlight on, so put the brightness back after.
    property Timer _colourSync: Timer {
        interval: 600
        onTriggered: {
            root._setColour.command = ["sh", "-c",
                'l=$(asusctl leds get | sed "s/.*: //" | tr A-Z a-z); '
                + 'asusctl aura effect static -c "$1" && [ -n "$l" ] && asusctl leds set "$l"',
                "_", root.colour.toString().slice(1)]
            root._setColour.running = true
        }
    }
    property Process _setColour: Process { onExited: root.refresh() }

    property Connections _config: Connections {
        target: Config
        function onKbdBacklightChanged() { root.refresh() }
    }
    property Connections _deck: Connections {
        target: Sh
        function onDeckShownChanged() { if (Sh.deckShown) root.refresh() }
    }
    Component.onCompleted: refresh()
}
