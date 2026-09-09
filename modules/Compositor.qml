pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

QtObject {
    id: root

    function _norm(s) {
        return String(s || "").toLowerCase().replace(/\.desktop$/, "")
    }

    function find(names) {
        const pats = (names || []).filter(s => s && String(s).length).map(root._norm)
        if (!pats.length) return null

        const tls = (ToplevelManager.toplevels && ToplevelManager.toplevels.values) || []
        let best = null, bs = 0
        for (const tl of tls) {
            const a = root._norm(tl.appId)
            const t = String(tl.title || "").toLowerCase()
            let s = 0
            if (a) for (const p of pats) {
                if (a === p) s = Math.max(s, 4)
                else if (a.indexOf(p) >= 0 || p.indexOf(a) >= 0) s = Math.max(s, 3)
            }
            if (!s) for (const p of pats) if (t.indexOf(p) >= 0) s = Math.max(s, 1)
            if (s > bs) { bs = s; best = tl }
        }
        return best
    }

    function isRunning(names) { return root.find(names) !== null }

    function raiseOrRun(names, onMiss) {
        const tl = root.find(names)
        if (tl) tl.activate()
        else if (onMiss) onMiss()
    }

    function focus(names) { root.raiseOrRun(names, null) }
}
