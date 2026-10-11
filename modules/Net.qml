pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// Wi-Fi, Bluetooth and traffic for the deck's Network page. Throughput is sampled from
// /proc/net/dev every second while the page is open and once a minute otherwise, which is
// enough to keep a per-day total (in $XDG_STATE_HOME/gimbal/traffic.json) across reboots.
QtObject {
    id: root

    // Set by the page while it's on screen.
    property bool live: false

    // Wi-Fi
    readonly property var wifi: ((Networking.devices && Networking.devices.values) || [])
        .find(d => d.type === DeviceType.Wifi) || null
    readonly property bool wifiOn: Networking.wifiEnabled
    function setWifi(on) { Networking.wifiEnabled = on }

    // Strongest entry per name; connected, then saved, then by signal.
    readonly property var networks: {
        const all = (root.wifi && root.wifi.networks && root.wifi.networks.values) || []
        const best = {}
        for (const n of all) {
            if (!n.name) continue
            const b = best[n.name]
            if (!b || n.connected || (!b.connected && n.signalStrength > b.signalStrength)) best[n.name] = n
        }
        return Object.keys(best).map(k => best[k]).sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    }
    readonly property var current: root.networks.find(n => n.connected) || null
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full

    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }
    function strengthGlyph(s) {
        return s > 0.66 ? Sh.icWifi : s > 0.4 ? Sh.icWifiHigh : s > 0.15 ? Sh.icWifiLow : Sh.icWifiZero
    }
    function scan(on) { if (root.wifi) root.wifi.scannerEnabled = on }

    // Bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!root.adapter && root.adapter.enabled
    function setBt(on) { if (root.adapter) root.adapter.enabled = on }
    readonly property var devices: {
        const all = (root.adapter && root.adapter.devices && root.adapter.devices.values) || []
        return all.filter(d => d.paired || d.connected || (d.name && d.name !== d.address))
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    }
    function discover(on) { if (root.adapter && root.adapter.enabled) root.adapter.discovering = on }
    function deviceGlyph(d) {
        const i = String(d.icon || "")
        return /headset|headphone|audio-head/.test(i) ? Sh.icHeadphones
             : /mouse/.test(i) ? Sh.icMouse
             : /keyboard/.test(i) ? Sh.icKeyboard
             : /joystick|gaming/.test(i) ? Sh.icGamepad
             : /phone/.test(i) ? Sh.icPhone
             : /speaker|audio-card/.test(i) ? Sh.icSpeaker
             : /watch/.test(i) ? Sh.icWatch
             : /computer/.test(i) ? Sh.icLaptop
             : Sh.icBluetooth
    }

    // Formatting
    function bytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (n >= 1000 && i < u.length - 1) { n /= 1000; i++ }
        return (i === 0 ? Math.round(n) : n < 10 ? n.toFixed(1) : Math.round(n)) + " " + u[i]
    }
    function rate(n) { return root.bytes(n) + "/s" }

    // Throughput
    readonly property int window: 60                 // seconds of history in the graph
    property var rxHist: []
    property var txHist: []
    readonly property real rxRate: root.rxHist.length ? root.rxHist[root.rxHist.length - 1] : 0
    readonly property real txRate: root.txHist.length ? root.txHist[root.txHist.length - 1] : 0
    property var _prev: null                         // { t, rx, tx } raw counters at the last sample

    // Physical links only; tunnels like tailscale0 would count the same bytes twice.
    function _counters(text) {
        let rx = 0, tx = 0
        for (const ln of text.split("\n")) {
            const m = /^\s*([^:\s]+):\s*(.*)$/.exec(ln)
            if (!m || !/^(wl|en|eth|ww|usb)/.test(m[1])) continue
            const f = m[2].trim().split(/\s+/)
            rx += Number(f[0]) || 0
            tx += Number(f[8]) || 0
        }
        return { rx: rx, tx: tx }
    }

    property Process _dev: Process {
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector { onStreamFinished: root._sample(root._counters(this.text)) }
    }
    property Timer _tick: Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.live ? 1000 : 60000
        onTriggered: if (!root._dev.running) root._dev.running = true
    }
    onLiveChanged: if (root.live) { root.rxHist = []; root.txHist = []; root._prev = null; root.refreshLink() }

    function _sample(c) {
        const now = Date.now(), p = root._prev
        root._prev = { t: now, rx: c.rx, tx: c.tx }
        root._count(c)
        if (!p || !root.live) return
        const dt = Math.max(0.2, (now - p.t) / 1000)
        const push = (h, v) => { const a = h.concat([Math.max(0, v)]); return a.length > root.window ? a.slice(-root.window) : a }
        root.rxHist = push(root.rxHist, (c.rx - p.rx) / dt)
        root.txHist = push(root.txHist, (c.tx - p.tx) / dt)
    }

    // Daily totals, per connection: "YYYY-MM-DD" → { "<connection>": [rx, tx] }. Bytes go to
    // whatever you were connected through when they were counted.
    property var days: ({})
    property var _base: null                         // { boot, rx, tx } counters already counted
    property string _boot: ""
    property bool _loaded: false
    readonly property string _path: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal/traffic.json"

    readonly property string connection: root.current ? root.current.name
        : root.iface && !/^wl/.test(root.iface) ? "Ethernet" : "Other"

    function _day(d) {
        const p = n => String(n).padStart(2, "0")
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
    }
    function _sum(by) {
        let rx = 0, tx = 0
        for (const k in by || {}) { rx += by[k][0]; tx += by[k][1] }
        return [rx, tx]
    }
    // The last `n` days, oldest first: [{ key, label, rx, tx, by }].
    function recent(n) {
        const out = [], d = new Date()
        d.setDate(d.getDate() - (n - 1))
        for (let i = 0; i < n; i++) {
            const k = root._day(d), by = root.days[k] || {}, s = root._sum(by)
            out.push({ key: k, label: d.toLocaleDateString(Qt.locale(), "ddd").slice(0, 2), rx: s[0], tx: s[1], by: by })
            d.setDate(d.getDate() + 1)
        }
        return out
    }
    // Per-connection totals over some days, biggest first: [{ name, rx, tx }].
    function byConnection(list) {
        const acc = {}
        for (const d of list) for (const k in d.by) {
            const a = acc[k] || (acc[k] = [0, 0])
            a[0] += d.by[k][0]; a[1] += d.by[k][1]
        }
        return Object.keys(acc).map(k => ({ name: k, rx: acc[k][0], tx: acc[k][1] }))
            .sort((a, b) => (b.rx + b.tx) - (a.rx + a.tx))
    }

    function _count(c) {
        if (!root._loaded || !root._boot) return
        const b = root._base, first = !b
        // Counters restart from zero after a reboot or when an interface comes back.
        const same = b && b.boot === root._boot && c.rx >= b.rx && c.tx >= b.tx
        const drx = same ? c.rx - b.rx : c.rx, dtx = same ? c.tx - b.tx : c.tx
        root._base = { boot: root._boot, rx: c.rx, tx: c.tx }
        if (first) { root._dirty = true; root._write() }
        if (!drx && !dtx) return
        const k = root._day(new Date()), days = Object.assign({}, root.days)
        const by = Object.assign({}, days[k] || {}), v = by[root.connection] || [0, 0]
        by[root.connection] = [v[0] + drx, v[1] + dtx]
        days[k] = by
        for (const key of Object.keys(days).sort().slice(0, -90)) delete days[key]
        root.days = days
        root._dirty = true
    }
    property bool _dirty: false
    property Timer _save: Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: root._write()
    }
    function _write() {
        if (!root._dirty) return
        root._dirty = false
        const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'"
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname " + q(root._path) + ")\" && printf '%s' "
            + q(JSON.stringify({ days: root.days, base: root._base })) + " > " + q(root._path + ".tmp")
            + " && mv " + q(root._path + ".tmp") + " " + q(root._path)])
    }

    property Process _bootId: Process {
        running: true
        command: ["cat", "/proc/sys/kernel/random/boot_id"]
        stdout: StdioCollector { onStreamFinished: root._boot = this.text.trim() }
    }
    // Read a moment after start, so a shell reload sees what the previous instance saved
    // on its way out instead of counting the same bytes again.
    property bool _settled: false
    property Timer _settle: Timer { running: true; interval: 1500; onTriggered: root._settled = true }
    property FileView _file: FileView {
        path: root._settled ? root._path : ""
        onLoaded: {
            try {
                const j = JSON.parse(text() || "{}")
                // Older files kept one [rx, tx] per day.
                const days = j.days || {}
                for (const k in days) if (Array.isArray(days[k])) days[k] = { "Other": days[k] }
                root.days = days
                root._base = j.base || null
            } catch (e) {}
            root._loaded = true
        }
        onLoadFailed: root._loaded = true
    }

    // Addresses and Tailscale, read while the page is open.
    property string address: ""
    property string gateway: ""
    property string iface: ""
    property string tailscale: ""                    // "", "Off", "Logged out", or the tailnet IP
    property int tailPeers: 0

    function refreshLink() {
        if (!root._wlan.running) root._wlan.running = true
        if (!root._route.running) root._route.running = true
        if (!root._ts.running) root._ts.running = true
    }
    property Timer _linkTick: Timer {
        running: root.live
        repeat: true
        interval: 10000
        onTriggered: root.refreshLink()
    }
    property Process _route: Process {
        command: ["sh", "-c", "ip -4 route show default | head -1; ip -4 -o addr show scope global"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const r = /via (\S+) dev (\S+)/.exec(lines[0] || "")
                root.gateway = r ? r[1] : ""
                root.iface = r ? r[2] : ""
                const a = lines.slice(1).map(l => /^\d+:\s+(\S+)\s+inet\s+([\d.]+)/.exec(l)).find(m => m && m[1] === root.iface)
                root.address = a ? a[2] : ""
            }
        }
    }
    // The Wi-Fi link: band, channel and the rate negotiated with the access point.
    property var wlan: ({ band: "", channel: "", rate: "" })
    property Process _wlan: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,CHAN,FREQ,RATE", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ln = this.text.split("\n").find(l => l.startsWith("*:"))
                const f = ln ? ln.split(":") : []
                const mhz = parseInt(f[2]) || 0
                root.wlan = { channel: f[1] || "", rate: (f[3] || "").replace("Mbit/s", "Mb/s"),
                              band: mhz >= 5925 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : mhz ? "2.4 GHz" : "" }
            }
        }
    }

    // When each Bluetooth device connected (address → ms), noticed every few seconds.
    property var btSince: ({})
    property Timer _btTick: Timer {
        running: true
        repeat: true
        interval: root.live ? 2000 : 15000
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now(), next = {}
            for (const d of root.devices) if (d.connected) next[d.address] = root.btSince[d.address] || now
            root.btSince = next
        }
    }
    function duration(ms) {
        const m = Math.floor(ms / 60000), h = Math.floor(m / 60)
        return h ? h + "h " + (m % 60) + "m" : m ? m + "m" : "just now"
    }

    property Process _ts: Process {
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(this.text) } catch (e) {}
                if (!j) { root.tailscale = ""; return }
                const s = j.BackendState
                root.tailscale = s === "Running" ? ((j.Self && j.Self.TailscaleIPs && j.Self.TailscaleIPs[0]) || "Connected")
                               : s === "NeedsLogin" ? "Logged out" : s === "Stopped" ? "Off" : (s || "")
                root.tailPeers = s === "Running" ? Object.values(j.Peer || {}).filter(p => p.Online).length : 0
            }
        }
        onExited: (code) => { if (code !== 0 && root.tailscale === "") root.tailscale = "" }
    }

    Component.onDestruction: root._write()
}
