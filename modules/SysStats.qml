pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// CPU / RAM / GPU load for the dashboard. Samples only while the dashboard is open.
QtObject {
    id: root

    readonly property bool _on: Sh.deckShown

    property real cpu: 0       // 0..1
    property real memUsed: 0   // GiB
    property real memTotal: 0  // GiB
    property real gpu: -1      // 0..1, -1 when the driver doesn't report it
    property real temp: -1     // CPU package °C, -1 when unknown
    property var cpuHist: []   // last 40 samples (60s), for the sparkline

    property var _prev: null

    property Timer _tick: Timer {
        interval: 1500
        repeat: true
        triggeredOnStart: true
        running: root._on
        onTriggered: _read.running = true
        onRunningChanged: if (!running) root._prev = null
    }

    property Process _read: Process {
        command: ["sh", "-c",
            'head -1 /proc/stat; grep -E "^(MemTotal|MemAvailable):" /proc/meminfo; '
            + 'g=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); echo "${g:--}"; '
            + 'for h in /sys/class/hwmon/hwmon*; do case "$(cat $h/name 2>/dev/null)" in k10temp|coretemp|zenpower) cat $h/temp1_input; break;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const ln = this.text.split("\n")
                const c = ln[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = c[3] + (c[4] || 0)
                const total = c.reduce((a, b) => a + b, 0)
                if (root._prev) {
                    const dt = total - root._prev.total
                    if (dt > 0) {
                        root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prev.idle) / dt))
                        root.cpuHist = root.cpuHist.concat([root.cpu]).slice(-40)
                    }
                }
                root._prev = { idle: idle, total: total }

                const kb = k => { const r = ln.find(l => l.startsWith(k)); return r ? parseInt(r.split(/\s+/)[1]) : 0 }
                const tot = kb("MemTotal:"), avail = kb("MemAvailable:")
                root.memTotal = tot / 1048576
                root.memUsed = (tot - avail) / 1048576

                const g = parseInt(ln[3])
                root.gpu = isNaN(g) ? -1 : g / 100

                const tc = parseInt(ln[4])
                root.temp = isNaN(tc) ? -1 : tc / 1000
            }
        }
    }
}
