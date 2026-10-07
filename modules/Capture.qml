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

    property bool busy: false
    property bool pickerActive: false
    property string _pickerFor: ""
    property bool _quiet: false

    // Still of the whole layout taken before a region pick: the picker shows it and the
    // selection is cropped from it, so the screen is frozen while you drag.
    property string frozen: ""

    property bool recording: false
    property string recFile: ""
    property double recStartAt: 0

    property string error: ""
    property double errorAt: 0
    function _fail(msg) {
        root.error = msg
        root.errorAt = Date.now()
    }

    // Bounding box of all outputs in logical coords; grim's full capture covers exactly this.
    readonly property var layout: {
        const s = Quickshell.screens
        if (!s || s.length === 0) return { x: 0, y: 0, w: 1, h: 1 }
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        for (const m of s) {
            x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y)
            x1 = Math.max(x1, m.x + m.width); y1 = Math.max(y1, m.y + m.height)
        }
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }

    function _stamp() {
        const d = new Date()
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
            + "_" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
    }
    function _notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Gimbal", title, body])
    }
    function _done(code, outText, errText) {
        root.busy = false
        if (code !== 0) { root._fail(errText.trim() || "screenshot failed"); return }
        if (root._quiet) { root._notify("Screenshot", "Copied to clipboard"); return }
        const path = outText.trim()
        if (!path.length) { root._fail("screenshot failed"); return }
        root.lastShot = path
        root._notify("Screenshot", "Saved and copied")
    }

    function shot(mode) {
        if (root.busy) return
        root.error = ""
        root.busy = true
        const m = mode || "region"
        root._quiet = /-quiet$/.test(m)
        root._pickerFor = m.replace(/-quiet$/, "") === "region" ? "shot" : ""
        // From the launcher, let its 110ms close finish so it isn't in the grab.
        _grabDelay.interval = Sh.launcherShown ? 160 : 0
        Sh.closeLauncher()
        _grabDelay.restart()
    }
    property Timer _grabDelay: Timer {
        onTriggered: {
            if (root._pickerFor === "shot") { _freeze.running = true; return }
            _shot.out = root.shotDir + "/Screenshot_" + root._stamp() + ".png"
            _shot.quiet = root._quiet ? "1" : "0"
            _shot.running = true
        }
    }

    function openLast() {
        if (root.lastShot.length) Quickshell.execDetached(["xdg-open", root.lastShot])
    }

    property Process _shot: Process {
        property string out: ""
        property string quiet: "0"
        command: ["sh", "-c",
            'q="$2"; out="$1"; '
            + 'if [ "$q" = "1" ]; then grim - | wl-copy --type image/png || exit 2; exit 0; fi; '
            + 'mkdir -p "$(dirname "$out")"; grim "$out" || exit 2; '
            + 'wl-copy --type image/png < "$out" 2>/dev/null & printf %s "$out"',
            "_", _shot.out, _shot.quiet]
        stdout: StdioCollector { id: _shotOut }
        stderr: StdioCollector { id: _shotErr }
        onExited: (code) => root._done(code, _shotOut.text, _shotErr.text)
    }

    // Uncompressed PPM: the grab is ~10ms, so the picker appears without a visible delay.
    property Process _freeze: Process {
        command: ["sh", "-c",
            'f=$(mktemp --suffix=.ppm -p "${XDG_RUNTIME_DIR:-/tmp}" gimbal-freeze-XXXXXX) || exit 2; '
            + 'grim -t ppm "$f" || { rm -f "$f"; exit 2; }; printf %s "$f"']
        stdout: StdioCollector { id: _freezeOut }
        onExited: (code) => {
            root.frozen = code === 0 ? _freezeOut.text.trim() : ""
            root.pickerActive = true
        }
    }

    function _dropFrozen() {
        if (root.frozen.length) Quickshell.execDetached(["rm", "-f", root.frozen])
        root.frozen = ""
    }

    function _regionPicked(gx, gy, gw, gh) {
        root.pickerActive = false
        if (gw < 4 || gh < 4) { root._regionCancelled(); return }
        const geom = Math.round(gx) + "," + Math.round(gy) + " " + Math.round(gw) + "x" + Math.round(gh)
        if (root._pickerFor === "record") {
            root.recFile = root.recDir + "/Recording_" + root._stamp() + ".mp4"
            _recRegion.geom = geom
            _regionSettle.restart()
            return
        }
        const out = root.shotDir + "/Screenshot_" + root._stamp() + ".png"
        const q = root._quiet ? "1" : "0"
        if (root.frozen.length) {
            const L = root.layout
            _crop.args = [root.frozen, out, q, String(L.w),
                String(gx - L.x), String(gy - L.y), String(gw), String(gh)]
            root.frozen = ""
            _crop.running = true
        } else {
            // Freeze grab failed: fall back to grabbing the live screen once the picker is gone.
            _grimRegion.geom = geom
            _grimRegion.out = out
            _grimRegion.quiet = q
            _regionSettle.restart()
        }
    }
    property Timer _regionSettle: Timer {
        interval: 60
        onTriggered: root._pickerFor === "record" ? (_recRegion.running = true) : (_grimRegion.running = true)
    }
    function _regionCancelled() {
        root.pickerActive = false
        root.busy = false
        root._dropFrozen()
    }

    property Process _crop: Process {
        property var args: []
        command: ["sh", "-c",
            'f="$1"; out="$2"; q="$3"; trap \'rm -f "$f"\' EXIT; '
            + 'iw=$(magick identify -format %w "$f") || exit 2; '
            + 'crop=$(awk -v iw="$iw" -v lw="$4" -v x="$5" -v y="$6" -v w="$7" -v h="$8" '
            + '\'BEGIN { k = iw / lw; printf "%dx%d+%d+%d", w*k + .5, h*k + .5, x*k + .5, y*k + .5 }\'); '
            + 'if [ "$q" = "1" ]; then magick "$f" -crop "$crop" +repage png:- | wl-copy --type image/png || exit 2; exit 0; fi; '
            + 'mkdir -p "$(dirname "$out")"; magick "$f" -crop "$crop" +repage "$out" || exit 2; '
            + 'wl-copy --type image/png < "$out" 2>/dev/null & printf %s "$out"',
            "_"].concat(_crop.args)
        stdout: StdioCollector { id: _cropOut }
        stderr: StdioCollector { id: _cropErr }
        onExited: (code) => root._done(code, _cropOut.text, _cropErr.text)
    }

    property Process _grimRegion: Process {
        property string geom: ""
        property string out: ""
        property string quiet: "0"
        command: ["sh", "-c",
            'geom="$1"; q="$3"; out="$2"; '
            + 'if [ "$q" = "1" ]; then grim -g "$geom" - | wl-copy --type image/png || exit 2; exit 0; fi; '
            + 'mkdir -p "$(dirname "$out")"; grim -g "$geom" "$out" || exit 2; '
            + 'wl-copy --type image/png < "$out" 2>/dev/null & printf %s "$out"',
            "_", _grimRegion.geom, _grimRegion.out, _grimRegion.quiet]
        stdout: StdioCollector { id: _grimRegionOut }
        stderr: StdioCollector { id: _grimRegionErr }
        onExited: (code) => root._done(code, _grimRegionOut.text, _grimRegionErr.text)
    }

    function recToggle() {
        if (root.recording) root.recStop()
        else root.recStart("full")
    }
    function recStart(mode) {
        if (root.recording) return
        root.error = ""
        if ((mode || "full") === "region") {
            root._pickerFor = "record"
            root.frozen = ""
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
            if (code !== 0 && code !== 130 && code !== 1)
                root._fail(_recRegionErr.text.trim() || "recording failed")
        }
    }
}
