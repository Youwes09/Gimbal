pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string _dir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal"
    readonly property string _path: _dir + "/frecency.json"

    property var _data: ({})

    property int rev: 0

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function bump(key) {
        if (!key) return
        const d = root._data
        const e = d[key] || { n: 0, t: 0 }
        e.n += 1
        e.t = Math.floor(Date.now() / 1000)
        d[key] = e
        root._data = d
        root.rev++
        _saveTimer.restart()
    }

    function score(key) {
        const e = root._data[key]
        if (!e) return 0
        const ageDays = (Date.now() / 1000 - e.t) / 86400
        const recency = Math.pow(0.5, ageDays / 7)
        return e.n * (0.3 + 0.7 * recency)
    }

    function top(prefix, n) {
        const _ = root.rev
        return Object.keys(root._data)
            .filter(k => k.indexOf(prefix) === 0)
            .map(k => ({ k: k, s: root.score(k) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .slice(0, n)
            .map(x => x.k)
    }

    property FileView _file: FileView {
        path: root._path
        onLoaded:     { try { root._data = JSON.parse(text() || "{}") } catch (e) { root._data = ({}) } }
        onLoadFailed: root._data = ({})
    }

    property Timer _saveTimer: Timer {
        interval: 500
        onTriggered: Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + root._q(root._dir) + " && printf '%s' "
            + root._q(JSON.stringify(root._data)) + " > " + root._q(root._path)])
    }
}
