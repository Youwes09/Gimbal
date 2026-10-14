pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

QtObject {
    id: root

    property real pct: 1.0
    property bool available: false
    property bool _heard: false

    function _parse(text, key) {
        const m = String(text || "").match(new RegExp(key + "=(\\d+)%"))
        return m ? parseInt(m[1]) : null
    }

    function refresh() {
        _get.running = false
        Qt.callLater(() => _get.running = true)
    }
    Component.onCompleted: root.refresh()

    property Process _get: Process {
        command: ["sh", "-c",
            'o=$(oledctl brightness get 2>/dev/null); '
            + 'if [ $? -eq 0 ] && [ -n "$o" ]; then printf %s "$o"; else '
            + 'printf "current=%s" "$(brightnessctl -m info 2>/dev/null | cut -d, -f4)"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root._parse(this.text, "current")
                if (v !== null && root._heard && root.available && v !== Math.round(root.pct * 100))
                    Osd.pulse("brightness")
                root._heard = false
                if (v !== null) { root.pct = v / 100; root.available = true }
            }
        }
    }

    // Every write to the backlight, from anyone (brightnessctl, oledctl, another script), comes
    // through udev; those get the popup too when the level moved. A fade is many writes, so reads
    // follow it at most every 100 ms. Without udevadm there's nothing to watch.
    property Process _watch: Process {
        command: ["sh", "-c", 'command -v udevadm >/dev/null || exit 127; '
            + 'exec udevadm monitor --udev --subsystem-match=backlight']
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (!/\bchange\b/.test(line)) return
                root._heard = true
                if (root._pace.running) { root._more = true; return }
                root.refresh()
                root._pace.start()
            }
        }
        onExited: (code) => { if (code !== 127) root._rewatch.restart() }
    }
    property bool _more: false
    property Timer _pace: Timer {
        interval: 100
        onTriggered: { if (!root._more) return; root._more = false; root.refresh(); start() }
    }
    property Timer _rewatch: Timer { interval: 2000; onTriggered: root._watch.running = true }

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
