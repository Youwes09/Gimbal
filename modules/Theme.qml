pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

QtObject {
    id: root

    // Every size in the shell goes through s(). "auto" takes the G14's 243 PPI panel as 1.0.
    readonly property real scale: {
        const v = String(Config.scale).trim()
        if (v === "auto") {
            const sc = Quickshell.screens[0]
            return sc && sc.physicalPixelDensity > 0 ? sc.physicalPixelDensity * 25.4 / 243 : 1
        }
        const n = parseFloat(v)
        return n > 0 ? n : 1
    }
    // Anything with a size keeps at least a pixel.
    function s(px) {
        const v = Math.round(px * root.scale)
        return px > 0 ? Math.max(1, v) : v
    }

    property var c: ({})

    property FileView _file: FileView {
        path: Quickshell.env("GIMBAL_COLORS")
              || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                  + "/gimbal/colors.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded:      root.c = JSON.parse(text() || "{}")
        onLoadFailed:  root.c = ({})
    }

    function _v(k, fallback) { return root.c[k] !== undefined ? root.c[k] : fallback }

    readonly property color bg:       _v("background",             "#0a0908")
    readonly property color surface:  _v("surface",                "#0c0c10")
    readonly property color elevated: _v("surface_container_high", "#17161c")
    readonly property color fg:       _v("on_surface",             "#f3ede4")
    readonly property color muted:    _v("on_surface_variant",     "#968b7c")
    readonly property color accent:   _v("primary",                "#e8a24a")
    readonly property color rim:      _v("outline",                "#2b2620")
    readonly property color contrast: _v("contrast",               "#4a90e8")
    readonly property color second:   _v("secondary",              "#4ae8a2")
    readonly property color third:    _v("tertiary",               "#a24ae8")
    readonly property color error:    _v("error",                  "#e85a5a")
}
