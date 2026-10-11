pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// CPU, memory, GPU and temperature for the deck's tiles. Samples only while the deck is open.
// Each tile can flip to a second view (`views`); the choice lasts across opens.
QtObject {
    id: root

    readonly property bool _on: Sh.deckShown

    property real cpu: 0         // 0..1
    property real mhz: 0         // average clock across cores
    property real maxMhz: 0
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property real temp: -1       // CPU package °C, -1 when unknown

    // One entry per GPU: { card, vendor, name, busy (0..1 or -1), asleep, memUsed, memTotal (GiB, 0 if unknown) }
    property var gpus: []
    property int gpuIndex: 0
    readonly property var gpu: root.gpus[root.gpuIndex] || null
    // The GPU whose memory the memory tile shows: the first one that reports it.
    readonly property var vramGpu: root.gpus.find(g => g.memTotal > 0) || null

    // Which view each tile shows: cpu 0 load · 1 clock; mem 0 RAM · 1 VRAM; temp 0 heat · 1 power.
    property var views: ({ cpu: 0, mem: 0, temp: 0 })
    function flip(tile) {
        if (tile === "gpu") { if (root.gpus.length) root.gpuIndex = (root.gpuIndex + 1) % root.gpus.length; return }
        const n = tile === "mem" && !root.vramGpu ? 1 : 2
        const v = Object.assign({}, root.views)
        v[tile] = (v[tile] + 1) % n
        root.views = v
    }

    property var _prev: null

    // GPUs are found once: card, PCI vendor and the marketing name from lspci.
    property Process _find: Process {
        running: true
        // Names come from the pci.ids database next to lspci, by the IDs sysfs keeps: asking the
        // device itself (lspci) would wake a sleeping GPU.
        command: ["sh", "-c",
            'ids="$(dirname "$(readlink -f "$(command -v lspci)")")/../share/pci.ids"; '
            + 'for c in /sys/class/drm/card[0-9]*; do case "$c" in *-*) continue;; esac; '
            + 'v=$(cat $c/device/vendor 2>/dev/null) || continue; d=$(cat $c/device/device); '
            + 'n=$(awk -v v="${v#0x}" -v d="${d#0x}" \x27$1 == v && !/^\t/ { in_v = 1; next } in_v && /^[^\t#]/ { exit } in_v && $1 == d { $1 = ""; sub(/^[ \t]+/, ""); print; exit }\x27 "$ids" 2>/dev/null); '
            + 'echo "$(basename $c)|$v|$n"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const tidy = n => { const b = /\[([^\]]+)\]/.exec(n); return (b ? b[1] : n).replace(/^GeForce /, "").replace(/ Mobile$/, "").replace(/^(\S+) .* \/ /, "$1 ") }
                root.gpus = this.text.split("\n").filter(l => l).map(l => {
                    const f = l.split("|")
                    const vendor = f[1] === "0x1002" ? "amd" : f[1] === "0x10de" ? "nvidia" : f[1] === "0x8086" ? "intel" : "other"
                    return { card: f[0], vendor: vendor, name: tidy(f[2] || "") || vendor.toUpperCase(),
                             busy: -1, asleep: false, memUsed: 0, memTotal: 0 }
                })
                // Integrated first: that's the one drawing the desktop.
                .sort((a, b) => (b.vendor === "amd" || b.vendor === "intel") - (a.vendor === "amd" || a.vendor === "intel"))
            }
        }
    }

    property Timer _tick: Timer {
        interval: 1500
        repeat: true
        triggeredOnStart: true
        running: root._on
        onTriggered: if (!_read.running) _read.running = true
        onRunningChanged: if (!running) root._prev = null
    }

    // Plain key=value lines. A sleeping GPU is only asked whether it's asleep, so opening the
    // deck never wakes it.
    property Process _read: Process {
        command: ["sh", "-c",
            'echo "stat=$(head -1 /proc/stat)"; grep -E "^(MemTotal|MemAvailable):" /proc/meminfo | tr -d " " | sed "s/:/=/;s/kB//"; '
            + 'echo "mhz=$(awk -F: \'/^cpu MHz/{s+=$2;n++} END{if(n) printf \"%d\", s/n}\' /proc/cpuinfo)"; '
            + 'echo "maxmhz=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0) / 1000 ))"; '
            + 'for h in /sys/class/hwmon/hwmon*; do case "$(cat $h/name 2>/dev/null)" in k10temp|coretemp|zenpower) echo "temp=$(cat $h/temp1_input)"; break;; esac; done; '
            + 'for c in /sys/class/drm/card[0-9]*; do case "$c" in *-*) continue;; esac; d=$c/device; k=$(basename $c); '
            + 'pm=$(cat $d/power/runtime_status 2>/dev/null); echo "$k.pm=$pm"; [ "$pm" = suspended ] && continue; '
            + '[ -r $d/gpu_busy_percent ] && echo "$k.busy=$(cat $d/gpu_busy_percent)"; '
            + '[ -r $d/mem_info_vram_used ] && echo "$k.mem=$(( $(cat $d/mem_info_vram_used) + $(cat $d/mem_info_gtt_used 2>/dev/null || echo 0) ))/$(( $(cat $d/mem_info_vram_total) + $(cat $d/mem_info_gtt_total 2>/dev/null || echo 0) ))"; '
            + 'done']
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {}
                for (const ln of this.text.split("\n")) { const i = ln.indexOf("="); if (i > 0) kv[ln.slice(0, i)] = ln.slice(i + 1) }

                const c = (kv.stat || "").trim().split(/\s+/).slice(1).map(Number)
                const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0)
                if (root._prev) {
                    const dt = total - root._prev.total
                    if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prev.idle) / dt))
                }
                root._prev = { idle: idle, total: total }

                const tot = parseInt(kv.MemTotal) || 0, avail = parseInt(kv.MemAvailable) || 0
                root.memTotal = tot / 1048576
                root.memUsed = (tot - avail) / 1048576
                root.mhz = parseInt(kv.mhz) || 0
                root.maxMhz = parseInt(kv.maxmhz) || 0
                const tc = parseInt(kv.temp)
                root.temp = isNaN(tc) ? -1 : tc / 1000

                root.gpus = root.gpus.map(g => {
                    const m = (kv[g.card + ".mem"] || "").split("/").map(Number), b = parseInt(kv[g.card + ".busy"])
                    return Object.assign({}, g, {
                        asleep: kv[g.card + ".pm"] === "suspended",
                        busy: isNaN(b) ? -1 : b / 100,
                        memUsed: m[1] ? m[0] / 1073741824 : g.memUsed,
                        memTotal: m[1] ? m[1] / 1073741824 : g.memTotal
                    })
                })
            }
        }
    }
}
