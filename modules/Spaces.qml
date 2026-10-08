pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Workspaces (mango tags) and their windows, live from mmsg. The layout is also kept on disk:
// this session's, which becomes "last session" at the next login, and named setups. Restoring
// one moves windows that are already open onto their workspaces and launches the rest.
QtObject {
    id: root

    property var clients: []          // [{ id, pid, appid, title, tag, monitor, focused, floating, x, y, w, h }]
    property var monitors: ({})       // name → { x, y, w, h }
    property string monitor: ""       // the focused one
    property int active: 1

    property var last: null           // { at, windows }
    property var setups: []           // [{ name, at, windows }]

    // Windows per tag, 1..9, left to right.
    function group(windows) {
        const t = []
        for (let i = 0; i < 9; i++) t.push([])
        for (const w of windows || []) if (w.tag >= 1 && w.tag <= 9) t[w.tag - 1].push(w)
        for (const l of t) l.sort((a, b) => a.x - b.x || a.y - b.y)
        return t
    }
    readonly property var tags: root.group(root.clients)

    function geometry(name) {
        return root.monitors[name] || root.monitors[root.monitor] || { x: 0, y: 0, w: 16, h: 10 }
    }

    // Only cache hits: desktop entries load after the shell starts.
    property var _icons: ({})
    function icon(appid) {
        if (!appid) return ""
        if (root._icons[appid]) return root._icons[appid]
        const e = DesktopEntries.heuristicLookup(appid)
        const p = Quickshell.iconPath(e ? e.icon : appid, true)
        if (p) root._icons[appid] = p
        return p
    }

    function view(tag) { Quickshell.execDetached(["mmsg", "dispatch", "view," + tag + ",0"]) }
    function _move(id, tag) { Quickshell.execDetached(["mmsg", "dispatch", "tagsilent," + tag, "client," + id]) }

    function focus(w) {
        root.view(w.tag)
        const tls = (ToplevelManager.toplevels && ToplevelManager.toplevels.values) || []
        const tl = tls.find(t => t.appId === w.appid && t.title === w.title) || tls.find(t => t.appId === w.appid)
        if (tl) tl.activate()
    }

    // Live state
    property Process _watchClients: Process {
        command: ["mmsg", "watch", "all-clients"]
        running: true
        stdout: SplitParser { onRead: (line) => root._onClients(line) }
        onExited: root._rewatch.restart()
    }
    property Process _watchMonitors: Process {
        command: ["mmsg", "watch", "all-monitors"]
        running: true
        stdout: SplitParser { onRead: (line) => root._onMonitors(line) }
        onExited: root._rewatch.restart()
    }
    property Timer _rewatch: Timer {
        interval: 2000
        onTriggered: { root._watchClients.running = true; root._watchMonitors.running = true }
    }

    function _onClients(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { return }
        const list = (j.clients || [])
            .filter(c => !c.is_scratchpad && !c.is_namedscratchpad && !c.is_overlay && !c.is_global)
            .map(c => ({ id: c.id, pid: c.pid, appid: c.appid || "", title: c.title || "",
                         tag: (c.tags && c.tags[0]) || 0, monitor: c.monitor || "",
                         focused: !!c.is_focused, floating: !!c.is_floating,
                         x: c.x, y: c.y, w: c.width, h: c.height }))
        const fewer = list.length < root.clients.length
        root._park(list)
        root.clients = list
        root._place(list)
        // Closing windows waits longer before it's saved, so a logout that closes everything
        // one by one never gets recorded as the session.
        if (root._loaded) {
            root._persist.interval = fewer ? 30000 : 3000
            root._persist.restart()
        }
    }

    function _onMonitors(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { return }
        const m = {}
        for (const mon of j.monitors || []) {
            m[mon.name] = { x: mon.x, y: mon.y, w: mon.width, h: mon.height }
            if (mon.active) {
                root.monitor = mon.name
                const t = (mon.tags || []).find(t => t.is_active)
                if (t) root.active = t.index
            }
        }
        root.monitors = m
    }

    // A window closed into the tray keeps its place in the layout while the app runs, so a
    // restore wakes it back onto its workspace.
    property var _parked: ({})        // appid → last window
    function _park(list) {
        const open = {}
        for (const c of list) open[c.appid] = true
        const parked = {}
        for (const a in root._parked) if (!open[a]) parked[a] = root._parked[a]
        for (const c of root.clients)
            if (c.appid && !open[c.appid] && Compositor.findTray(root._names(c.appid))) parked[c.appid] = c
        root._parked = parked
    }
    function _names(appid) {
        const e = DesktopEntries.heuristicLookup(appid)
        return e ? [appid, e.startupClass, e.id, e.name] : [appid]
    }

    // Snapshots
    // Per pid: its command line (arguments joined by \037) and the working directory of its
    // first child, which for a terminal is its shell.
    readonly property string _procScript:
        'for p in "$@"; do [ -r /proc/$p/cmdline ] || continue; '
        + 'cmd=$(tr "\\0" "\\037" < /proc/$p/cmdline); '
        + 'c=$(cut -d" " -f1 /proc/$p/task/$p/children 2>/dev/null); '
        + 'cwd=""; [ -n "$c" ] && cwd=$(readlink /proc/$c/cwd 2>/dev/null); '
        + 'printf "%s\\t%s\\t%s\\n" "$p" "$cmd" "$cwd"; done'

    property Process _procs: Process {
        property var list: []
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {}
                for (const ln of this.text.split("\n")) {
                    const f = ln.split("\t")
                    if (f.length < 3) continue
                    info[f[0]] = { cmd: f[1].split("\x1f").filter(s => s.length), cwd: f[2] }
                }
                const windows = root._procs.list.map(c => {
                    const p = info[String(c.pid)] || {}
                    return { tag: c.tag, appid: c.appid, title: c.title, monitor: c.monitor,
                             floating: c.floating, x: c.x, y: c.y, w: c.w, h: c.h,
                             cmd: p.cmd || [], cwd: p.cwd || "" }
                })
                if (root._procs.done) root._procs.done({ at: Date.now(), windows: windows })
            }
        }
    }
    function _snapshot(done) {
        const parked = Object.keys(root._parked).map(a => root._parked[a])
            .filter(c => Compositor.findTray(root._names(c.appid)))
        const list = root.clients.concat(parked).filter(c => c.appid && c.tag > 0)
        if (!list.length || root._procs.running) return
        root._procs.list = list
        root._procs.done = done
        root._procs.command = ["sh", "-c", root._procScript, "_"]
            .concat([...new Set(list.map(c => String(c.pid)))])
        root._procs.running = true
    }

    property Timer _persist: Timer {
        onTriggered: root._snapshot(s => { root._current = s; root._write() })
    }

    function saveSetup(name) {
        root._snapshot(s => {
            const rest = root.setups.filter(x => x.name !== name)
            root.setups = rest.concat([Object.assign({ name: name }, s)])
            root._write()
        })
    }
    function deleteSetup(name) {
        root.setups = root.setups.filter(x => x.name !== name)
        root._write()
    }
    function loadSetup(name) {
        const s = root.setups.find(x => x.name === name)
        if (s) root.restore(s)
    }

    // Restore
    readonly property var _termFlags: ({
        foot: ["--working-directory"], alacritty: ["--working-directory"],
        kitty: ["--directory"], ghostty: ["--working-directory"], wezterm: ["start", "--cwd"]
    })
    function _terminal(appid) {
        const t = String(Config.terminal || "foot").split(/\s+/)[0].split("/").pop()
        return appid === t || root._termFlags[appid] ? appid : ""
    }
    function _argv(w) {
        const term = root._terminal(w.appid)
        if (term) {
            const flags = root._termFlags[term]
            return w.cwd && flags ? [term].concat(flags, [w.cwd]) : [term]
        }
        const e = DesktopEntries.heuristicLookup(w.appid)
        if (e && e.command && e.command.length) return e.command
        // Some apps rewrite their process title into one string; child processes of
        // multi-process apps carry --type=… and can't start the app.
        const cmd = (w.cmd || []).length === 1 ? w.cmd[0].split(/\s+/) : (w.cmd || [])
        return cmd.some(a => /^--type=/.test(a)) ? [] : cmd
    }

    property var _pending: []          // [{ appid, tag }] waiting for a window to appear
    property var _known: ({})
    property Timer _expire: Timer { interval: 30000; onTriggered: root._pending = [] }

    function restore(snap) {
        if (!snap || !snap.windows) return
        const want = snap.windows.slice().sort((a, b) => a.tag - b.tag || a.x - b.x || a.y - b.y)
        const pool = root.clients.slice()
        const pending = [], launched = {}
        for (const w of want) {
            const i = pool.findIndex(c => c.appid === w.appid)
            if (i >= 0) {
                const c = pool.splice(i, 1)[0]
                if (c.tag !== w.tag) root._move(c.id, w.tag)
                continue
            }
            pending.push({ appid: w.appid, tag: w.tag })
            const argv = root._argv(w)
            // Terminals open one window per launch; anything else restores its own windows.
            const key = root._terminal(w.appid) ? "" : w.appid + " " + argv.join(" ")
            if (key && launched[key]) continue
            if (key) launched[key] = true
            // Running in the tray: wake it, relaunching only if that brings up no window.
            Compositor.wake(root._names(w.appid), () => { if (argv.length) Compositor.spawn(argv) })
        }
        const known = {}
        for (const c of root.clients) known[c.id] = true
        root._known = known
        root._pending = pending
        root._expire.restart()
    }

    function _place(list) {
        if (!root._pending.length) return
        for (const c of list) {
            if (root._known[c.id]) continue
            root._known[c.id] = true
            const i = root._pending.findIndex(p => p.appid === c.appid)
            if (i < 0) continue
            const p = root._pending.splice(i, 1)[0]
            if (c.tag !== p.tag) root._move(c.id, p.tag)
        }
    }

    // Storage
    // { session, current, last, setups }. A new session (boot id + compositor pid) turns the
    // previous one's layout into `last`.
    readonly property string _dir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal"
    readonly property string _path: _dir + "/spaces.json"

    property var _current: null
    property bool _loaded: false
    property string _session: ""
    property var _raw: null

    property Process _sessionId: Process {
        running: true
        command: ["sh", "-c", "cat /proc/sys/kernel/random/boot_id; pidof -s mango"]
        stdout: StdioCollector {
            onStreamFinished: { root._session = this.text.trim().replace(/\s+/g, ":"); root._reconcile() }
        }
    }
    property FileView _file: FileView {
        path: root._path
        onLoaded: {
            try { root._raw = JSON.parse(text() || "{}") }
            catch (e) {
                Quickshell.execDetached(["cp", "-f", root._path, root._path + ".bad"])
                root._raw = {}
            }
            root._reconcile()
        }
        onLoadFailed: { root._raw = {}; root._reconcile() }
    }

    function _usable(s) { return s && Array.isArray(s.windows) && s.windows.length > 0 }
    function _reconcile() {
        if (root._loaded || !root._session || root._raw === null) return
        const j = root._raw
        root.setups = Array.isArray(j.setups) ? j.setups : []
        if (j.session === root._session) {
            root.last = root._usable(j.last) ? j.last : null
            root._current = j.current || null
        } else {
            root.last = root._usable(j.current) ? j.current : root._usable(j.last) ? j.last : null
            root._current = null
        }
        root._loaded = true
        root._write()
        root._persist.interval = 3000
        root._persist.restart()
    }

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function _write() {
        if (!root._loaded) return
        const data = { session: root._session, current: root._current, last: root.last, setups: root.setups }
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + root._q(root._dir) + " && printf '%s' " + root._q(JSON.stringify(data))
            + " > " + root._q(root._path + ".tmp") + " && mv " + root._q(root._path + ".tmp")
            + " " + root._q(root._path)])
    }
}
