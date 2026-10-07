pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// The folders you open most from the launcher, with their git state. Refreshed each time the deck opens.
QtObject {
    id: root

    property var list: []   // [{ path, name, short, branch, dirty, last }]
    readonly property int dirtyCount: root.list.filter(p => p.dirty > 0).length

    function refresh() {
        const dirs = Frecency.top("dir:", 3).map(k => k.slice(4))
        if (dirs.length === 0) { root.list = []; return }
        _git.command = ["sh", "-c",
            'for d in "$@"; do [ -d "$d" ] || continue; '
            + 'b=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null); '
            + 'n=$([ -n "$b" ] && git -C "$d" status --porcelain 2>/dev/null | wc -l || echo 0); '
            + 't=$(git -C "$d" log -1 --format=%ct 2>/dev/null); '
            + 'printf "%s\\t%s\\t%s\\t%s\\n" "$d" "$b" "$n" "$t"; done',
            "_"].concat(dirs)
        _git.running = true
    }

    property Connections _open: Connections {
        target: Sh
        function onDeckShownChanged() { if (Sh.deckShown) root.refresh() }
    }
    Component.onCompleted: root.refresh()   // first use happens after the deck has already opened

    property Process _git: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME")
                root.list = this.text.split("\n").filter(l => l.length).map(l => {
                    const [path, branch, dirty, last] = l.split("\t")
                    return {
                        path: path,
                        name: path.replace(/\/+$/, "").split("/").pop(),
                        short: path.indexOf(home) === 0 ? "~" + path.slice(home.length) : path,
                        branch: branch || "",
                        dirty: parseInt(dirty) || 0,
                        last: (parseInt(last) || 0) * 1000
                    }
                })
            }
        }
    }

    // Opens the way the launcher learned you like for this folder.
    function open(path) {
        Frecency.bump("dir:" + path)
        const s = k => Frecency.score("diropen|" + k + "|" + path)
        const e = s("editor"), f = s("files"), t = s("terminal"), m = Math.max(e, f, t)
        const how = m > 0 ? (e === m ? "editor" : f === m ? "files" : "terminal") : Config.dirOpen
        Frecency.bump("diropen|" + how + "|" + path)
        if (how === "files") Places.openManager(path)
        else if (how === "terminal") Places.openTerminal(path, true)
        else if (how === "editor") Places.openEditor(path)
        else Places.openSmart(path)
    }
}
