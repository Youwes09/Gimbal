pragma Singleton

import QtQuick
import Quickshell
import "root:/modules"

QtObject {
    id: root

    readonly property string _override: Quickshell.env("GIMBAL_WALLPAPER") || ""
    readonly property string path: root._override.length > 0
        ? root._override
        : Wallpapers.current

    readonly property url source: root.path.length === 0
        ? ""
        : (root.path.startsWith("file://") ? root.path : "file://" + root.path)
}
