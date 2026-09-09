pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

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
}
