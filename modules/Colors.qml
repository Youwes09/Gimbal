pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string _cfgDir: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/gimbal"
    readonly property string _out: _cfgDir + "/colors.json"

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function regenerate(src) {
        if (!src || src.length === 0) return
        const p = src.indexOf("://") >= 0 ? src.replace(/^file:\/\//, "") : src
        if (_ex.running) { _ex._pending = p; return }

        _ex.command = ["magick", p, "-resize", "160x160", "-depth", "8",
            "-colors", "10", "-format", "%c", "histogram:info:"]
        _ex.running = true
    }

    function _rgbToHsl(r, g, b) {
        r /= 255; g /= 255; b /= 255
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn
        let h = 0
        const l = (mx + mn) / 2
        const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
        if (d !== 0) {
            if (mx === r)      h = ((g - b) / d) % 6
            else if (mx === g) h = (b - r) / d + 2
            else               h = (r - g) / d + 4
            h *= 60; if (h < 0) h += 360
        }
        return [h, s, l]
    }
    function _hslToHex(h, s, l) {
        h = ((h % 360) + 360) % 360
        s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l))
        const c = (1 - Math.abs(2 * l - 1)) * s
        const x = c * (1 - Math.abs((h / 60) % 2 - 1))
        const m = l - c / 2
        let r = 0, g = 0, b = 0
        if      (h < 60)  { r = c; g = x }
        else if (h < 120) { r = x; g = c }
        else if (h < 180) { g = c; b = x }
        else if (h < 240) { g = x; b = c }
        else if (h < 300) { r = x; b = c }
        else              { r = c; b = x }
        const hx = v => Math.round((v + m) * 255).toString(16).padStart(2, "0")
        return "#" + hx(r) + hx(g) + hx(b)
    }
    function _fromHistogram(histText) {
        const rows = []
        const re = /([0-9]+):\s*\(\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)/g
        let m
        while ((m = re.exec(histText)) !== null) {
            const hsl = _rgbToHsl(parseFloat(m[2]), parseFloat(m[3]), parseFloat(m[4]))
            rows.push({ count: parseInt(m[1]), h: hsl[0], s: hsl[1], l: hsl[2] })
        }
        if (rows.length === 0) return null

        let dom = rows[0]
        for (const x of rows) if (x.count > dom.count) dom = x
        const h = dom.h
        const tint = Math.max(0.04, Math.min(0.15, dom.s))

        let acc = null, best = -1
        for (const x of rows) {
            if (x.s < 0.28 || x.l < 0.12 || x.l > 0.9) continue
            const score = x.s * Math.pow(x.count, 0.35)
            if (score > best) { best = score; acc = x }
        }
        if (!acc) for (const x of rows) if (!acc || x.l > acc.l) acc = x

        // State colours rotate around the accent so they always read as distinct from it.
        const accS = Math.max(0.5, Math.min(0.8, acc.s))
        const accL = Math.max(0.58, Math.min(0.68, acc.l))

        return {
            background:             _hslToHex(h, tint * 0.9, 0.045),
            surface:                _hslToHex(h, tint * 0.8, 0.075),
            surface_container_high: _hslToHex(h, tint * 0.7, 0.13),
            on_surface:             _hslToHex(h, tint * 0.45, 0.93),
            on_surface_variant:     _hslToHex(h, tint * 0.5, 0.60),
            outline:                _hslToHex(h, tint * 0.7, 0.22),
            primary:                _hslToHex(acc.h,
                Math.max(0.5, Math.min(0.9, acc.s)),
                Math.max(0.55, Math.min(0.72, acc.l))),
            contrast:               _hslToHex(acc.h + 180, accS, accL),
            secondary:              _hslToHex(acc.h + 120, accS, accL),
            tertiary:               _hslToHex(acc.h - 120, accS, accL),
            error:                  _hslToHex(0, 0.78, 0.6)
        }
    }

    function _derive(text) {
        const t = (text || "").trim()
        if (t.length === 0) return null
        return _fromHistogram(t)
    }

    property Process _ex: Process {
        property string _pending: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const pal = root._derive(this.text || "")
                if (pal)
                    Quickshell.execDetached(["sh", "-c",
                        "mkdir -p " + root._q(root._cfgDir) + " && printf '%s' "
                        + root._q(JSON.stringify(pal, null, 2)) + " > " + root._q(root._out)])
            }
        }
        onRunningChanged: {
            if (!running && _pending.length > 0) {
                const p = _pending; _pending = ""
                Qt.callLater(() => root.regenerate(p))
            }
        }
    }

    function _sync() {
        const src = Wallpapers.currentIsVideo ? Wallpapers.currentPoster : Wallpapers.current
        if (src && src.length > 0) root.regenerate(src)
    }

    property Connections _watch: Connections {
        target: Wallpapers

        function onCurrentChanged()       { Qt.callLater(root._sync) }
        function onCurrentPosterChanged() { Qt.callLater(root._sync) }
        function onPosterRevChanged()     { if (Wallpapers.currentIsVideo) Qt.callLater(root._sync) }
    }

    Component.onCompleted: Qt.callLater(root._sync)
}
