pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

QtObject {
    id: root

    property real pct: 1.0
    property bool available: false

    function _parse(text, key) {
        const m = String(text || "").match(new RegExp(key + "=(\\d+)%"))
        return m ? parseInt(m[1]) : null
    }

    function refresh() {
        _get.running = false
        Qt.callLater(() => _get.running = true)
    }
    Component.onCompleted: root.refresh()

    // oledctl (wayoled) is the real control — it drives the panel through the
    // display-protection daemon's own curve. brightnessctl is only a fallback
    // for when that daemon isn't up (missing socket, not started yet, etc).
    property Process _get: Process {
        command: ["sh", "-c",
            'o=$(oledctl brightness get 2>/dev/null); '
            + 'if [ $? -eq 0 ] && [ -n "$o" ]; then printf %s "$o"; else '
            + 'printf "current=%s" "$(brightnessctl -m info 2>/dev/null | cut -d, -f4)"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root._parse(this.text, "current")
                if (v !== null) { root.pct = v / 100; root.available = true }
            }
        }
    }

    function set(p) {
        const target = Math.round(Math.max(0, Math.min(1, p)) * 100)
        Osd.pulse("brightness")
        _cmd.command = ["sh", "-c",
            'o=$(oledctl brightness set ' + target + ' 2>/dev/null); '
            + 'if [ $? -eq 0 ] && [ -n "$o" ]; then printf %s "$o"; else '
            + 'brightnessctl set ' + target + '% >/dev/null 2>&1; printf "target=%s%%" ' + target + '; fi']
        _cmd.running = true
    }
    function nudge(deltaPct) {
        const step = (deltaPct >= 0 ? "+" : "") + Math.round(deltaPct * 100)
        Osd.pulse("brightness")
        _cmd.command = ["sh", "-c",
            'o=$(oledctl brightness step ' + step + ' 2>/dev/null); '
            + 'if [ $? -eq 0 ] && [ -n "$o" ]; then printf %s "$o"; else '
            + 'brightnessctl set ' + step + '% >/dev/null 2>&1; '
            + 'printf "target=%s" "$(brightnessctl -m info 2>/dev/null | cut -d, -f4)"; fi']
        _cmd.running = true
    }

    property Process _cmd: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root._parse(this.text, "target")
                if (v !== null) { root.pct = v / 100; root.available = true }
            }
        }
    }
}
