pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

QtObject {
    id: root

    readonly property string _home: Quickshell.env("HOME")
    readonly property string shotDir: Quickshell.env("XDG_SCREENSHOTS_DIR") || (root._home + "/Pictures/Screenshots")
    readonly property string recDir: root._home + "/Videos/Recordings"

    property string lastShot: ""
    property var list: []
    property int idx: -1

    property int shotW: 0
    property int shotH: 0
    property int shotBytes: 0
    property string shotFmt: ""
    property double shotAt: 0

    property bool busy: false
    property bool pickerActive: false
    property string _pickerFor: ""

    property bool recording: false
    property string recFile: ""
    property double recStartAt: 0

    property string error: ""
    property double errorAt: 0
    function _fail(msg) {
        root.error = msg
        root.errorAt = Date.now()
    }

    readonly property string activePath: {
        if (root.idx >= 0 && root.idx < root.list.length) return root.list[root.idx].path
        if (root.lastShot.length) return root.lastShot
        return root.list.length ? root.list[0].path : ""
    }
    onActivePathChanged: {
        if (!root.activePath.length) {
            root.shotW = 0; root.shotH = 0; root.shotBytes = 0; root.shotFmt = ""
            return
        }
        const row = root.list.find(x => x.path === root.activePath)
        root.shotAt = row ? row.mtime * 1000 : Date.now()
        _probe.path = root.activePath
        _probe.running = true
    }

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function _stamp() {
        const d = new Date()
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
            + "_" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
    }

    function shot(mode) {
        if (root.busy) return
        root.error = ""
        Sh.closeLauncher()
        Sh.close()
        Sh.captureVeil = true
        root.busy = true
        if ((mode || "region") === "region") {
            root._pickerFor = "shot"
            root.pickerActive = true
            return
        }
        _shot.out = root.shotDir + "/Screenshot_" + root._stamp() + ".png"
        _shotDelay.restart()
    }

    property Timer _shotDelay: Timer {
        interval: 220
        onTriggered: _shot.running = true
    }

    property Process _shot: Process {
        property string out: ""
        command: ["sh", "-c",
            'out="$1"; mkdir -p "$(dirname "$out")"; grim "$out" || exit 2; '
            + 'wl-copy --type image/png < "$out" 2>/dev/null; printf %s "$out"',
            "_", _shot.out]
        stdout: StdioCollector { id: _shotOut }
        stderr: StdioCollector { id: _shotErr }
        onExited: (code) => {
            root.busy = false
            Sh.captureVeil = false
            const path = _shotOut.text.trim()
            if (code === 0 && path.length) root._ingest(path)
            else root._fail(_shotErr.text.trim() || "screenshot failed")
        }
    }

    function _regionPicked(gx, gy, gw, gh) {
        root.pickerActive = false
        if (gw < 4 || gh < 4) { root._regionCancelled(); return }
        const geom = Math.round(gx) + "," + Math.round(gy) + " " + Math.round(gw) + "x" + Math.round(gh)
        if (root._pickerFor === "record") {
            root.recFile = root.recDir + "/Recording_" + root._stamp() + ".mp4"
            _recRegion.geom = geom
            _recRegion.running = true
        } else {
            _grimRegion.geom = geom
            _grimRegion.out = root.shotDir + "/Screenshot_" + root._stamp() + ".png"
            _grimRegion.running = true
        }
    }
    function _regionCancelled() {
        root.pickerActive = false
        Sh.captureVeil = false
        root.busy = false
    }

    property Process _grimRegion: Process {
        property string geom: ""
        property string out: ""
        command: ["sh", "-c",
            'geom="$1"; out="$2"; mkdir -p "$(dirname "$out")"; grim -g "$geom" "$out" || exit 2; '
            + 'wl-copy --type image/png < "$out" 2>/dev/null; printf %s "$out"',
            "_", _grimRegion.geom, _grimRegion.out]
        stdout: StdioCollector { id: _grimRegionOut }
        stderr: StdioCollector { id: _grimRegionErr }
        onExited: (code) => {
            root.busy = false
            Sh.captureVeil = false
            const path = _grimRegionOut.text.trim()
            if (code === 0 && path.length) root._ingest(path)
            else root._fail(_grimRegionErr.text.trim() || "screenshot failed")
        }
    }

    function _ingest(path) {
        root.lastShot = path
        root.idx = -1
        root.refreshList()
        Sh.open("capture")
    }

    property Process _probe: Process {
        property string path: ""
        command: ["sh", "-c",
            'magick identify -format "%w %h %B %m" "$1" 2>/dev/null || stat -c "%s" "$1"',
            "_", _probe.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(/\s+/)
                if (p.length >= 4) {
                    root.shotW = parseInt(p[0]) || 0
                    root.shotH = parseInt(p[1]) || 0
                    root.shotBytes = parseInt(p[2]) || 0
                    root.shotFmt = p[3] || "PNG"
                } else if (p.length === 1) {
                    root.shotBytes = parseInt(p[0]) || 0
                    root.shotFmt = "PNG"
                }
            }
        }
    }

    function refreshList() {
        _scan.running = false
        Qt.callLater(() => _scan.running = true)
    }
    property Process _scan: Process {
        command: ["sh", "-c",
            'd="$1"; mkdir -p "$d"; cd "$d" 2>/dev/null || exit 0; '
            + 'for f in $(ls -t -- *.png 2>/dev/null); do printf "%s\\t%s\\n" "$(stat -c %Y -- "$f")" "$d/$f"; done',
            "_", root.shotDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const ln of this.text.split("\n")) {
                    if (!ln.length) continue
                    const i = ln.indexOf("\t")
                    if (i < 0) continue
                    out.push({ mtime: parseInt(ln.slice(0, i)) || 0, path: ln.slice(i + 1) })
                }
                root.list = out
            }
        }
    }

    function browse(delta) {
        if (!root.list.length) return
        let cur = root.idx
        if (cur < 0) {
            cur = root.lastShot.length ? Math.max(0, root.list.findIndex(x => x.path === root.lastShot)) : 0
        }
        root.idx = Math.max(0, Math.min(root.list.length - 1, cur + delta))
    }

    function copyImage() {
        if (!root.activePath.length) return
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "_", root.activePath])
    }
    function copyPath() {
        if (!root.activePath.length) return
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "_", root.activePath])
    }
    function open() {
        if (!root.activePath.length) return
        Quickshell.execDetached(["xdg-open", root.activePath])
    }
    function reveal() {
        if (!root.activePath.length) return
        Quickshell.execDetached(["sh", "-c",
            _q(Config.fileManager) + ' "$1" 2>/dev/null || xdg-open "$(dirname "$1")"',
            "_", root.activePath])
    }
    function annotate() {
        if (!root.activePath.length) return
        Sh.close()
        Quickshell.execDetached(["sh", "-c",
            'command -v satty >/dev/null || exit 0; '
            + 'satty --filename "$1" --output-filename "$1" --early-exit --initial-tool rectangle',
            "_", root.activePath])
    }
    function remove() {
        const p = root.activePath
        if (!p.length) return
        Quickshell.execDetached(["rm", "-f", p])
        if (p === root.lastShot) root.lastShot = ""
        root.list = root.list.filter(x => x.path !== p)
        root.idx = root.list.length ? Math.min(root.idx < 0 ? 0 : root.idx, root.list.length - 1) : -1
    }

    function recToggle() {
        if (root.recording) root.recStop()
        else root.recStart("full")
    }
    function recStart(mode) {
        if (root.recording) return
        root.error = ""
        Sh.closeLauncher()
        Sh.close()
        Sh.captureVeil = true
        if ((mode || "full") === "region") {
            root._pickerFor = "record"
            root.pickerActive = true
            return
        }
        root.recFile = root.recDir + "/Recording_" + root._stamp() + ".mp4"
        _recDelay.restart()
    }
    function recStop() {
        if (root.recording) _rec.signal(2)
        if (root._recRegionRunning) _recRegion.signal(2)
    }

    property Timer _recDelay: Timer {
        interval: 220
        onTriggered: _rec.running = true
    }

    property Process _rec: Process {
        command: ["sh", "-c",
            'out="$1"; mkdir -p "$(dirname "$out")"; '
            + 'command -v wl-screenrec >/dev/null || { echo "wl-screenrec not installed" >&2; exit 3; }; '
            + 'exec wl-screenrec -f "$out"',
            "_", root.recFile]
        stderr: StdioCollector { id: _recErr }
        onStarted: {
            root.recording = true
            root.recStartAt = Date.now()
        }
        onExited: (code) => {
            root.recording = false
            Sh.captureVeil = false
            if (code !== 0 && code !== 130 && code !== 1)
                root._fail(_recErr.text.trim() || "recording failed")
        }
    }

    readonly property bool _recRegionRunning: _recRegion.running
    property Process _recRegion: Process {
        property string geom: ""
        command: ["sh", "-c",
            'geom="$1"; out="$2"; mkdir -p "$(dirname "$out")"; '
            + 'command -v wl-screenrec >/dev/null || { echo "wl-screenrec not installed" >&2; exit 3; }; '
            + 'exec wl-screenrec -g "$geom" -f "$out"',
            "_", _recRegion.geom, root.recFile]
        stderr: StdioCollector { id: _recRegionErr }
        onStarted: {
            root.recording = true
            root.recStartAt = Date.now()
        }
        onExited: (code) => {
            root.recording = false
            Sh.captureVeil = false
            if (code !== 0 && code !== 130 && code !== 1)
                root._fail(_recRegionErr.text.trim() || "recording failed")
        }
    }
}
