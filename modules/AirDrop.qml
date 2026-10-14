pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// AirDrop through omdrop (Config.airdrop): whether this machine is receiving and visible to
// nearby Apple devices, a switch, who's nearby and sending to them. Nothing polls: `ip monitor`
// sleeps until awdl0 (omdrop's AirDrop link) or Config.airdropAdapter comes or goes, and only
// then is omdrop asked, every 2 s until the change has settled.
QtObject {
    id: root

    readonly property bool enabled: Config.airdrop
    property bool available: false     // omdrop answered
    property bool receiving: false
    property bool visible: false       // the radio is advertising, not just the receiver up
    property string name: ""
    property real until: 0             // when the window closes (ms), 0 when open-ended
    property real since: 0             // when receiving started (ms)
    readonly property bool busy: root._toggle.running
    // Why the last switch failed: omdrop's last line on stderr.
    readonly property string error: !root.busy && root._code !== 0 ? root._err : ""
    property int _code: 0
    property string _err: ""
    property bool _link: false         // awdl0 exists
    // Coming up: an adapter was just plugged in, or the radio is on its way, and not visible yet.
    readonly property bool starting: root._settle.running && root._rising && !root.visible
    property bool _rising: false       // the change being watched is towards on
    property bool _adopt: false        // Config.airdropAdapter arrived; its window isn't ours yet

    // How long turning it on here keeps this machine visible; remembered across restarts.
    readonly property var windows: [{ id: "10m", label: "10 min" }, { id: "1h", label: "1 hour" },
                                    { id: "forever", label: "Until off" }, { id: "once", label: "One file" }]
    property string window: "10m"
    readonly property string windowLabel: (root.windows.find(w => w.id === root.window) || root.windows[0]).label
    function nextWindow() {
        const i = root.windows.findIndex(w => w.id === root.window)
        root.window = root.windows[(i + 1) % root.windows.length].id
        root._save()
        if (root.receiving) root._applyWindow.restart()
    }
    // While on, a new choice replaces the open window once the cycling stops.
    property Timer _applyWindow: Timer {
        interval: 1200
        onTriggered: if (root.receiving && !root.busy) {
            root._rewindow.command = ["omdrop", "on", root.window]
            root._rewindow.running = true
        }
    }
    property Process _rewindow: Process { onExited: root.refresh() }

    // Devices starred by name (an iPhone's address changes every session; its name doesn't). A
    // favorite accepted with "Always accept" is also a known sender: no prompt from them.
    property var favorites: []
    function isFavorite(name) { return !!name && root.favorites.indexOf(name) >= 0 }
    function toggleFavorite(name) {
        if (root.isFavorite(name)) root.removeFavorite(name)
        else if (name) { root.favorites = root.favorites.concat([name]); root._save() }
    }
    function removeFavorite(name) {
        root.favorites = root.favorites.filter(n => n !== name)
        root._save()
        const known = root.senders.filter(e => e.label === name)
        if (known.length) root._forget(known)
    }

    // What came in and went out, newest first: [{ dir: "in" | "out", who, files, folder, time,
    // outcome }], outcome "declined" or "missed" (no answer in time) for what never came in.
    property var history: []
    function _record(e) {
        root.history = [Object.assign({ time: Date.now() }, e)].concat(root.history).slice(0, 30)
        root._save()
    }
    // Opens a received file, or its folder when it was several.
    function openEntry(e) {
        if (!e || e.dir !== "in" || !e.folder || e.outcome) return
        Quickshell.execDetached(["xdg-open", e.files.length === 1 ? e.folder + "/" + e.files[0] : e.folder])
    }

    function _save() {
        root._state.setText(JSON.stringify({ window: root.window, favorites: root.favorites, history: root.history }))
    }
    property FileView _state: FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal/airdrop.json"
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                if (root.windows.some(x => x.id === j.window)) root.window = j.window
                if (Array.isArray(j.favorites)) root.favorites = j.favorites.filter(n => typeof n === "string")
                if (Array.isArray(j.history)) root.history = j.history.filter(e => e && Array.isArray(e.files))
            } catch (e) {}
        }
    }

    // omdrop's known senders, accepted without a prompt. "Always accept" writes a "# name" line
    // over the hashes it remembers; an email or phone added with `omdrop senders` is its own label.
    property var senders: []           // [{ label, lines }]
    function _forget(entries) {
        const drop = [].concat(...entries.map(e => e.lines))
        const keep = root._senderLines.filter(l => drop.indexOf(l) < 0)
        root._edit.command = ["sh", "-c", 'printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "_",
                              root.knownSenders, keep.length ? keep.join("\n") + "\n" : ""]
        root._edit.running = true
    }
    property Process _edit: Process { onExited: root._sendersFile.reload() }
    property var _senderLines: []
    property FileView _sendersFile: FileView {
        path: root.knownSenders
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: { root._senderLines = []; root.senders = [] }
        onLoaded: {
            const lines = text().split("\n").filter(l => l.trim().length > 0)
            const out = []
            let label = "", labelLine = ""
            for (const l of lines) {
                const t = l.trim()
                if (t.startsWith("#")) { label = t.replace(/^#\s*/, ""); labelLine = l; continue }
                const hash = /^[0-9a-fA-F]{64}$/.test(t)
                const last = out[out.length - 1]
                if (hash && last && last.hashed && last.labelLine === labelLine) last.lines.push(l)
                else out.push({ label: hash ? (label || "Unnamed sender") : t, hashed: hash, labelLine: labelLine,
                                lines: hash && labelLine ? [labelLine, l] : [l] })
                if (!hash) { label = ""; labelLine = "" }
            }
            root._senderLines = text().split("\n").filter(l => l.length > 0)
            root.senders = out
        }
    }

    function refresh() { if (root.enabled && !root._status.running) root._status.running = true }
    function toggle() {
        if (!root.enabled || root.busy) return
        root._code = 0; root._err = ""
        root._rising = !root.receiving
        root._toggle.command = ["omdrop", "toggle", root.window]
        root._toggle.running = true
        root._watch()
    }

    // Asks again every 2 s until on and visible, or off with the link gone; 45 s at most.
    property int _left: 0
    function _watch() { root._left = 22; root.refresh(); root._settle.restart() }
    readonly property bool _settled: (root.receiving && root.visible) || (!root.receiving && !root._link)
    property Timer _settle: Timer {
        interval: 2000
        repeat: true
        onTriggered: {
            if (root._settled || --root._left <= 0) stop()
            else root.refresh()
        }
    }

    property Process _monitor: Process {
        running: root.enabled
        command: ["ip", "-o", "monitor", "link"]
        stdout: SplitParser {
            onRead: (line) => {
                const m = /^(Deleted )?\d+: ([^:@\s]+)[:@]/.exec(line)
                if (!m) return
                const adapter = !!Config.airdropAdapter && m[2] === Config.airdropAdapter
                if (m[2] !== "awdl0" && !adapter) return
                if (m[2] === "awdl0") root._link = !m[1]
                if (adapter) root._adopt = !m[1]
                root._rising = !m[1]
                root._watch()
            }
        }
        // ip exits if it's killed; come back rather than go blind.
        onExited: if (root.enabled) root._restart.start()
    }
    property Timer _restart: Timer { interval: 5000; onTriggered: root._monitor.running = root.enabled }

    property Process _hasLink: Process {
        command: ["test", "-e", "/sys/class/net/awdl0"]
        onExited: (code) => root._link = code === 0
    }

    property Process _status: Process {
        // omdrop's state, then when its receiver started (@unix seconds).
        command: ["sh", "-c", "omdrop status --json && systemctl --user show --timestamp=unix -p ActiveEnterTimestamp --value airdrop-receiver.service"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                let j = null
                try { j = JSON.parse(lines[0]) } catch (e) {}
                const t = /^@(\d+)/.exec(lines[1] || "")
                root.since = j && j.receiving && t ? Number(t[1]) * 1000 : 0
                root.available = !!j
                root.receiving = !!j && j.receiving
                root.visible = !!j && j.receiving && j.visible === true
                root.name = (j && j.name) || ""
                root.until = j && j.remaining ? Date.now() + j.remaining * 1000 : 0
                if (!root.receiving) root.peers = []
                // The adapter opened an open-ended window; it gets the length picked here.
                if (root._adopt && root.visible) {
                    root._adopt = false
                    if (j.mode === "forever" && root.window !== "forever") root._applyWindow.restart()
                }
            }
        }
        onExited: (code) => { if (code !== 0) { root.available = false; root.receiving = false; root.visible = false } }
    }

    // Off if receiving, on for `window` if not.
    property Process _toggle: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.trim().length > 0)
                root._err = lines.length ? lines[lines.length - 1] : ""
            }
        }
        onExited: (code) => { root._code = code; root._watch() }
    }

    // Who's nearby: [{ mac, rssi, name }], strongest first. Asking for names connects to each
    // device and announces this machine over Bluetooth for the ~20 s the lookup runs, so it
    // only happens on request (the AirDrop page asks while it's open).
    property var peers: []
    readonly property bool scanning: root._peers.running
    function scan() {
        if (!root.enabled || !root.receiving || root._peers.running) return
        root.peers = []
        root._peers.running = true
    }
    function stopScan() { root._peers.running = false }
    property Process _peers: Process {
        command: ["omdrop", "peers", "--json", "-n", "--stream"]
        stdout: SplitParser {
            onRead: (line) => {
                let p = null
                try { p = JSON.parse(line) } catch (e) {}
                if (!p || !p.mac) return
                const old = root.peers.find(x => x.mac === p.mac)
                if (old && !p.name) p.name = old.name
                root.peers = root.peers.filter(x => x.mac !== p.mac).concat([p])
                    .sort((a, b) => (root.isFavorite(b.name) - root.isFavorite(a.name))
                                    || (b.rssi || -999) - (a.rssi || -999))
            }
        }
    }

    // One send at a time: a file chooser, then omdrop's progress, then a notification.
    property string sendTo: ""         // mac being sent to
    property string sendName: ""
    property string sendLine: ""       // omdrop's latest line about it
    readonly property bool sending: root._send.running
    function send(peer) {
        if (!root.enabled || root._send.running || !peer) return
        root.sendTo = peer.mac
        root.sendName = peer.name || "the device"
        root.sendLine = "Choosing files…"
        root._sendErr = ""
        root._sent = []
        root._send.command = ["omdrop", "send", "--to", peer.mac, "--pick"]
        root._send.running = true
    }
    property string _sendErr: ""
    property var _sent: []             // what omdrop reported sent: "Sent NAME (SIZE)"
    property Process _send: Process {
        stdout: SplitParser {
            onRead: (line) => {
                const t = line.trim()
                if (!t) return
                root.sendLine = t
                const m = /^Sent (.+?)(?: \([^)]*\))?$/.exec(t)
                if (m) root._sent = root._sent.concat([m[1]])
            }
        }
        stderr: SplitParser { onRead: (line) => { if (line.trim()) root._sendErr = line.trim() } }
        onExited: (code) => {
            if (code === 0 && root._sent.length) root._record({ dir: "out", who: root.sendName, files: root._sent })
            root._sent = []
            // 1: the chooser was cancelled.
            if (code === 0) Quickshell.execDetached(["notify-send", "-a", "AirDrop", "Sent to " + root.sendName, root.sendLine])
            else if (code !== 1) Quickshell.execDetached(["notify-send", "-a", "AirDrop", "-u", "critical",
                "Couldn't send to " + root.sendName, root._sendErr || root.sendLine])
            root.sendTo = ""
            root.sendLine = ""
        }
    }

    // Transfers waiting for an answer, when omdrop's receiver is set to ask (config.toml:
    // ask = true): [{ id, sender, model, files, links, hashes, deadline, preview }], oldest
    // first. inotifywait sleeps on the receiver's asks folder while it's receiving.
    readonly property string _run: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    readonly property string _askDir: root._run + "/omdrop/asks"
    readonly property string knownSenders: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/omdrop/known-senders"
    property var asks: []
    property var _toRead: []

    function answer(id, verdict) {
        const r = root.asks.find(a => a.id === id)
        if (!r) return
        // "Always" remembers the sender by what they proved: their hashed Apple ID identifiers,
        // under a comment naming them, which is how the AirDrop page lists them.
        const lines = verdict === "always" && r.hashes.length
            ? ["# " + r.sender.replace(/[\r\n]/g, " ")].concat(r.hashes).join("\n") : ""
        Quickshell.execDetached(["sh", "-c",
            '[ -z "$3" ] || { mkdir -p "$(dirname "$4")" && printf "%s\\n" "$3" >> "$4"; }; printf %s "$2" > "$1.answer"',
            "_", root._askDir + "/" + id, verdict, lines, root.knownSenders])
        if (verdict === "always" && r.sender && !root.isFavorite(r.sender)) {
            root.favorites = root.favorites.concat([r.sender])
            root._save()
        }
        root._drop(id)
    }
    function _drop(id) {
        const r = root.asks.find(a => a.id === id)
        if (r && r.preview) Quickshell.execDetached(["rm", "-f", r.preview])
        root.asks = root.asks.filter(a => a.id !== id)
    }

    property Process _askWatch: Process {
        running: root.enabled && root.receiving
        command: ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; ls -- *.json 2>/dev/null; exec inotifywait -m -q -e moved_to,delete --format "%e %f" .',
                  "_", root._askDir]
        stdout: SplitParser {
            onRead: (line) => {
                const m = /^(?:(MOVED_TO|DELETE) )?([0-9a-f]+)\.json$/.exec(line.trim())
                if (!m) return
                if (m[1] === "DELETE") { root._drop(m[2]); return }
                if (root.asks.some(a => a.id === m[2]) || root._toRead.indexOf(m[2]) >= 0) return
                root._toRead = root._toRead.concat([m[2]])
                root._readNext()
            }
        }
        onRunningChanged: if (!running) { for (const a of root.asks) root._drop(a.id) }
    }

    // One request at a time: its JSON, then its preview as a PNG (Qt can't show JPEG 2000).
    function _readNext() {
        if (root._askRead.running || !root._toRead.length) return
        const id = root._toRead[0]
        root._toRead = root._toRead.slice(1)
        root._askRead.askId = id
        root._askRead.command = ["sh", "-c",
            'cat "$1/$2.json" || exit 1; echo; [ -f "$1/$2.jp2" ] && magick "$1/$2.jp2[0]" "$3" 2>/dev/null && printf %s "$3"',
            "_", root._askDir, id, root._run + "/gimbal-airdrop-" + id + ".png"]
        root._askRead.running = true
    }
    property Process _askRead: Process {
        property string askId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                let r = null
                try { r = JSON.parse(lines[0]) } catch (e) {}
                if (r && r.id === root._askRead.askId && Date.now() / 1000 < r.deadline) {
                    r.preview = (lines[1] || "").trim()
                    r.hashes = Array.isArray(r.hashes) ? r.hashes.filter(h => /^[0-9a-f]{64}$/.test(h)) : []
                    root.asks = root.asks.concat([r])
                }
            }
        }
        onExited: Qt.callLater(root._readNext)
    }

    // Arrivals as the receiver logs them: who asked, then what it stored. journalctl sleeps
    // between lines, and only runs while receiving.
    property string _from: ""
    property var _asked: []
    property string _folder: ""
    property Process _dir: Process {
        command: ["omdrop", "dir"]
        stdout: StdioCollector { onStreamFinished: root._folder = this.text.trim() }
    }
    property Process _arrivals: Process {
        running: root.enabled && root.receiving
        command: ["journalctl", "--user", "-u", "airdrop-receiver.service", "-f", "-n", "0", "-o", "cat"]
        stdout: SplitParser {
            onRead: (line) => {
                // "ask from NAME (MODEL): type files, 2 item(s): A public.png 5244B; B public.heic 26B"
                let m = /ask from (.+?) \([^)]*\): type [^,]*, \d+ item\(s\): (.*)$/.exec(line)
                if (m) {
                    root._from = m[1]
                    root._asked = m[2].split("; ").map(s => s.replace(/ \S+ \d+B$/, ""))
                    return
                }
                m = /ask answered by the person: decline|ask unanswered after/.exec(line)
                if (m) {
                    root._record({ dir: "in", who: root._from, files: root._asked, folder: "",
                                   outcome: /unanswered/.test(m[0]) ? "missed" : "declined" })
                    return
                }
                m = /upload \S+: stored (.+)$/.exec(line)
                if (m) { root._record({ dir: "in", who: root._from, files: m[1].split(", "), folder: root._folder }); return }
                m = /link stored as .+ -> (.+)$/.exec(line)
                if (m) root._record({ dir: "in", who: root._from, files: [m[1]], folder: "" })
            }
        }
        onRunningChanged: if (running) root._dir.running = true
    }

    onEnabledChanged: if (root.enabled) { root._hasLink.running = true; root.refresh() }
    Component.onCompleted: if (root.enabled) { root._hasLink.running = true; root.refresh() }
}
