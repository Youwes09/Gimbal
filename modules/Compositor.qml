pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

QtObject {
    id: root

    function _norm(s) {
        return String(s || "").toLowerCase().replace(/\.desktop$/, "").replace(/_status_icon_\d+$/, "")
    }

    function _score(cands, pats) {
        let s = 0
        for (const c of cands) {
            if (!c) continue
            for (const p of pats) {
                if (c === p) s = Math.max(s, 4)
                else if (c.indexOf(p) >= 0 || p.indexOf(c) >= 0) s = Math.max(s, 3)
            }
        }
        return s
    }

    function find(names) {
        const pats = (names || []).filter(s => s && String(s).length).map(root._norm)
        if (!pats.length) return null

        const tls = (ToplevelManager.toplevels && ToplevelManager.toplevels.values) || []
        let best = null, bs = 0
        for (const tl of tls) {
            const a = root._norm(tl.appId)
            const t = String(tl.title || "").toLowerCase()
            let s = root._score([a], pats)
            if (!s) for (const p of pats) if (t.indexOf(p) >= 0) s = 1
            if (s > bs) { bs = s; best = tl }
        }
        return best
    }

    // An editor window that already has this folder open. VS Code-family titles carry the
    // workspace name as its own " - " segment ("file - Provisional - VSCodium"); Zed and
    // others put it first. Matches on the folder's name, within editor windows only.
    readonly property var _editors: ["codium", "vscodium", "code", "code-oss", "cursor", "zed", "dev.zed.zed"]
    function findEditorFor(path) {
        const name = String(path || "").replace(/\/+$/, "").split("/").pop()
        if (!name) return null
        const ed = root._norm(String(Config.editor).split(/\s+/)[0].split("/").pop())
        const tls = (ToplevelManager.toplevels && ToplevelManager.toplevels.values) || []
        for (const tl of tls) {
            const a = root._norm(tl.appId)
            if (a !== ed && root._editors.indexOf(a) < 0) continue
            const parts = String(tl.title || "").split(/\s+[-—]\s+/)
            if (parts.indexOf(name) >= 0) return tl
        }
        return null
    }

    function findTray(names) {
        const pats = (names || []).filter(s => s && String(s).length).map(root._norm)
        if (!pats.length) return null

        const items = (SystemTray.items && SystemTray.items.values) || []
        let best = null, bs = 0
        for (const it of items) {
            const cands = [it.id, it.title, it.tooltipTitle].map(root._norm)
            const s = root._score(cands, pats)
            if (s > bs) { bs = s; best = it }
        }
        return bs >= 3 ? best : null
    }

    function spawn(argv) {
        if (!argv || !argv.length) return
        Quickshell.execDetached(
            ["env", "-u", "ELECTRON_RUN_AS_NODE", "-u", "NODE_OPTIONS"].concat(argv))
    }

    property var _killedAt: ({})
    function _recentlyKilled(pats) {
        const now = Date.now()
        for (const p of pats) {
            const t = root._killedAt[p]
            if (t && now - t < 4000) return true
        }
        return false
    }

    function raiseOrRun(names, onMiss) {
        const pats = (names || []).filter(s => s && String(s).length).map(root._norm)
        if (pats.length && root._recentlyKilled(pats)) { if (onMiss) onMiss(); return }
        const tl = root.find(names)
        if (tl) { tl.activate(); return }
        root.wake(names, onMiss)
    }

    // Brings back an app that lives in the tray with no window. Not every tray icon opens a
    // window when clicked (menu-only icons, apps that ignore Activate), so when none shows up
    // in time, onMiss runs instead: a second launch of a single-instance app raises it.
    function wake(names, onMiss) {
        const tr = root.findTray(names)
        if (!tr || tr.onlyMenu) { if (onMiss) onMiss(); return }
        tr.activate()
        root._waking = root._waking.concat([{ names: names, onMiss: onMiss, until: Date.now() + 1500 }])
        _wakeCheck.start()
    }
    property var _waking: []
    property Timer _wakeCheck: Timer {
        interval: 150; repeat: true
        onTriggered: {
            const now = Date.now(), left = []
            for (const w of root._waking) {
                if (root.find(w.names)) continue
                if (now < w.until) left.push(w)
                else if (w.onMiss) w.onMiss()
            }
            root._waking = left
            if (!left.length) stop()
        }
    }

    // Raises an app's window, waking it from the tray if that's where it is. Nothing is
    // launched unless the app is running.
    function focus(names) {
        if (!root.findTray(names)) { root.raiseOrRun(names, null); return }
        root.raiseOrRun(names, () => {
            const e = (names || []).map(n => n && DesktopEntries.heuristicLookup(n)).find(e => e)
            if (e && e.command && e.command.length) root.spawn(e.command)
        })
    }

    property var _killPats: []
    property string _killExec: ""
    function killApp(names, execHint) {
        root._killPats = (names || []).filter(s => s && String(s).length).map(root._norm)
        root._killExec = String(execHint || "").split("/").pop()
        if (!root._killPats.length && !root._killExec) return
        const now = Date.now()
        for (const p of root._killPats) root._killedAt[p] = now
        _killProc.running = false
        _killProc.running = true
    }

    property Process _killProc: Process {
        command: ["mmsg", "get", "all-clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let cs = []
                try { cs = (JSON.parse(text || "{}").clients) || [] } catch (e) {}
                const pats = root._killPats
                const pids = []
                for (const c of cs) {
                    const a = root._norm(c.appid)
                    const t = String(c.title || "").toLowerCase()
                    let m = false
                    if (a) for (const p of pats)
                        if (a === p || a.indexOf(p) >= 0 || p.indexOf(a) >= 0) m = true
                    if (!m) for (const p of pats) if (t.indexOf(p) >= 0) m = true
                    if (m && c.pid) pids.push(String(c.pid))
                }
                if (pids.length) Quickshell.execDetached(["kill"].concat(pids))
                if (root._killExec.length >= 5)
                    Quickshell.execDetached(["pkill", "-if", "--", root._killExec])
            }
        }
    }
}
