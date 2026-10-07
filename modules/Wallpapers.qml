pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string dir: Quickshell.env("GIMBAL_WALLPAPER_DIR")
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string _stateDir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal"
    readonly property string _statePath: _stateDir + "/wallpaper"
    readonly property string _posterDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/gimbal/posters"
    readonly property string _wideDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/gimbal/wide"

    property var list: []
    property string current: ""

    readonly property bool currentIsVideo: /\.(mp4|webm|mkv|mov)$/i.test(root.current)
    readonly property bool currentIsGif:   /\.gif$/i.test(root.current)

    readonly property var currentEntry: root.list.find(w => w.path === root.current) || null

    readonly property string currentPoster: (root.currentEntry && root.currentEntry.video)
        ? root.currentEntry.poster : ""

    signal changed(string path)

    property int posterRev: 0

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function _idx() { return root.list.findIndex(w => w.path === root.current) }

    function apply(path) {
        if (!path || path === root.current) return
        root.current = path

        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + _q(_stateDir) + " && printf '%s' " + _q(path) + " > " + _q(_statePath)])
        root.changed(path)
    }
    function byName(n) {
        if (!n) return ""
        const w = root.list.find(x => x.name === n
            || x.name.toLowerCase() === n.toLowerCase() || x.path === n)
        return w ? w.path : ""
    }
    function next()   { if (list.length) apply(list[(_idx() + 1 + list.length) % list.length].path) }
    function prev()   { if (list.length) apply(list[(_idx() - 1 + list.length) % list.length].path) }
    function random() {
        if (list.length < 2) { if (list.length) apply(list[0].path); return }
        let i = _idx(), n = i
        while (n === i) n = Math.floor(Math.random() * list.length)
        apply(list[n].path)
    }
    function rescan() { _scan.running = false; Qt.callLater(() => _scan.running = true) }

    property var _postersDone: ({})
    function _genPosters() {
        const vids = root.list.filter(w => w.video && !root._postersDone[w.poster])
        if (vids.length === 0 || _poster.running) return
        _poster._targets = vids.map(w => w.poster)
        _poster.command = ["sh", "-c",
            'd="$1"; mkdir -p "$d"; shift; for f in "$@"; do '
            + 'b=$(basename "$f"); n="${b%.*}"; o="$d/$n.jpg"; '
            + '[ -s "$o" ] || ffmpeg -y -ss 0 -i "$f" -frames:v 1 -vf scale=880:-2 "$o" '
            + '>/dev/null 2>&1; test -s "$o" && printf "%s\\n" "$o"; done',
            "_", root._posterDir].concat(vids.map(w => w.path))
        _poster.running = true
    }
    property Process _poster: Process {
        property var _targets: []
        stdout: StdioCollector {
            onStreamFinished: {
                const done = Object.assign({}, root._postersDone)
                this.text.trim().split("\n").filter(l => l.length > 0).forEach(o => done[o] = true)
                root._postersDone = done
            }
        }
        onExited: { root.posterRev++; root._genThumbs() }
    }

    // Small stills for the dashboard strip (images directly, videos from their poster).
    readonly property string _thumbDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/gimbal/thumbs"
    property int thumbRev: 0
    function _genThumbs() {
        if (_thumbs.running) { _thumbs.again = true; return }
        _thumbs.command = ["sh", "-c",
            'd="$1"; shift; mkdir -p "$d"; command -v magick >/dev/null 2>&1 || exit 0; '
            + 'for f in "$@"; do b=$(basename "$f"); n="${b%.*}"; o="$d/$n.jpg"; [ -s "$o" ] && continue; '
            + 'case "$f" in *.mp4|*.webm|*.mkv|*.mov) s="$(dirname "$d")/posters/$n.jpg"; [ -s "$s" ] || continue ;; *) s="$f[0]" ;; esac; '
            + 'magick "$s" -resize "480x300^" -gravity center -extent 480x300 -quality 88 "$o" >/dev/null 2>&1; done',
            "_", root._thumbDir].concat(root.list.map(w => w.path))
        _thumbs.running = true
    }
    property Process _thumbs: Process {
        property bool again: false
        onExited: {
            root.thumbRev++
            if (again) { again = false; Qt.callLater(root._genThumbs) }
        }
    }

    property int wideRev: 0
    property var _widesDone: ({})
    function _genWides() {
        const imgs = root.list.filter(w => !w.video && w.wide && !root._widesDone[w.wide])
        if (imgs.length === 0 || _wide.running) return
        _wide.command = ["sh", "-c",
            'd="$1"; mkdir -p "$d"; shift; command -v magick >/dev/null 2>&1 || exit 0; for f in "$@"; do '
            + 'b=$(basename "$f"); n="${b%.*}"; o="$d/$n.jpg"; '
            + '[ -s "$o" ] || magick "$f[0]" -resize "1920x1080>" -background black -alpha remove -alpha off -quality 92 "$o" '
            + '>/dev/null 2>&1; test -s "$o" && printf "%s\\n" "$o"; done',
            "_", root._wideDir].concat(imgs.map(w => w.path))
        _wide.running = true
    }
    property Process _wide: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const done = Object.assign({}, root._widesDone)
                this.text.trim().split("\n").filter(l => l.length > 0).forEach(o => done[o] = true)
                root._widesDone = done
            }
        }
        onExited: root.wideRev++
    }

    property Process _scan: Process {
        running: true
        command: ["sh", "-c",
            'cd "$1" 2>/dev/null || exit 0; '
            + 'ls -1 2>/dev/null | grep -iE "\\.(png|jpe?g|webp|gif|mp4|webm|mkv|mov)$" | sort',
            "_", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = this.text.trim().split("\n").filter(l => l.length > 0)
                root.list = files.map(f => {
                    const name  = f.replace(/\.[^.]+$/, "")
                    const video = /\.(mp4|webm|mkv|mov)$/i.test(f)
                    return {
                        path:   root.dir + "/" + f,
                        name:   name,
                        gif:    /\.gif$/i.test(f),
                        video:  video,
                        poster: video ? (root._posterDir + "/" + name + ".jpg") : "",
                        thumb:  root._thumbDir + "/" + name + ".jpg",
                        wide:   video ? "" : (root._wideDir + "/" + name + ".jpg")
                    }
                })
                if (root.current === "" || !root.list.some(w => w.path === root.current)) {
                    root._restore.running = false
                    Qt.callLater(() => root._restore.running = true)
                }
                root._genPosters()
                root._genWides()
                root._genThumbs()
            }
        }
    }

    property Process _restore: Process {
        command: ["sh", "-c", "cat " + root._q(root._statePath) + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                const hit = p.length > 0 && root.list.find(w => w.path === p || w.name === p
                    || (root.dir + "/" + p) === w.path)
                if (hit) root.current = hit.path
                else if (root.list.length > 0) root.current = root.list[0].path
            }
        }
    }

    property Timer _rescanTimer: Timer {
        interval: 45000; running: true; repeat: true
        onTriggered: root._scan.running = true
    }
}
