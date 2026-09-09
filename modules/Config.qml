pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string _home: Quickshell.env("HOME")
    readonly property string _path: (Quickshell.env("XDG_CONFIG_HOME")
        || (_home + "/.config")) + "/gimbal/config.json"

    property var _j: ({})

    function _expand(p) {
        return (p && p.indexOf("~") === 0) ? root._home + p.slice(1) : p
    }
    function _pick(key, envKey, def) {
        const e = envKey ? Quickshell.env(envKey) : ""
        if (e && e.length > 0) return e
        const v = root._j[key]
        if (v !== undefined && v !== null && v !== "") return v
        return def
    }

    readonly property string editor:
        _pick("editor", "GIMBAL_EDITOR", Quickshell.env("EDITOR") || "codium")
    readonly property string fileManager:
        _pick("fileManager", "GIMBAL_FILE_MANAGER", "nautilus")
    readonly property string terminal:
        _pick("terminal", "GIMBAL_TERMINAL", Quickshell.env("TERMINAL") || "foot")

    readonly property string dirOpen:
        _pick("dirOpen", "GIMBAL_DIR_OPEN", "smart")

    readonly property bool raiseRunning:
        root._j.raiseRunning !== undefined ? !!root._j.raiseRunning : true

    readonly property var notifications:
        (root._j.notifications && typeof root._j.notifications === "object")
            ? root._j.notifications : ({})

    readonly property var fileRoots: {
        const env = (Quickshell.env("GIMBAL_FILE_ROOTS") || "").split(":").filter(s => s.length > 0)
        if (env.length > 0) return env.map(root._expand)
        if (Array.isArray(root._j.fileRoots) && root._j.fileRoots.length > 0)
            return root._j.fileRoots.map(root._expand)
        return [_home + "/Projects", _home + "/Documents", _home + "/Downloads",
                _home + "/Pictures", _home + "/.config"]
    }

    property FileView _file: FileView {
        path: root._path
        watchChanges: true
        onFileChanged: reload()
        onLoaded:      { try { root._j = JSON.parse(text() || "{}") } catch (e) { root._j = ({}) } }
        onLoadFailed:  root._j = ({})
    }
}
