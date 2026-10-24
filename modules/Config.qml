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

    // UI scale: a number, or "auto" to follow the screen's pixel density (see Theme.scale).
    readonly property var scale: _pick("scale", "GIMBAL_SCALE", 1)
    // Per-surface multipliers on top of `scale`, e.g. { "bar": 1.1, "deck": 0.9 }.
    readonly property var scales:
        (root._j.scales && typeof root._j.scales === "object") ? root._j.scales : ({})
    function scaleOf(part) {
        const n = parseFloat(root.scales[part])
        return n > 0 ? n : 1
    }

    // The bar: off by default; true or "top", or "bottom".
    readonly property string bar: {
        const v = String(_pick("bar", "GIMBAL_BAR", "")).toLowerCase()
        return v === "bottom" ? "bottom" : ["true", "top", "on", "1"].indexOf(v) >= 0 ? "top" : ""
    }

    // Keyboard backlight backend: "auto" | "asusctl" | "upower" | "brightnessctl" | "none".
    readonly property string kbdBacklight: _pick("kbdBacklight", "GIMBAL_KBD_BACKLIGHT", "auto")

    readonly property bool raiseRunning:
        root._j.raiseRunning !== undefined ? !!root._j.raiseRunning : true

    // Seconds of idle before the rest screen, and before it fades to black. 0 disables.
    readonly property int idleRest: root._j.idleRest !== undefined ? root._j.idleRest : 300
    readonly property int idleDark: root._j.idleDark !== undefined ? root._j.idleDark : 600
    // Media playing in any other player counts as activity, for apps whose video never asks
    // the compositor to stay awake (WebKit, some browsers). Names match the player's desktop
    // entry or identity, lowercase.
    readonly property var idleMusicPlayers: Array.isArray(root._j.idleMusicPlayers)
        ? root._j.idleMusicPlayers.map(s => String(s).toLowerCase()) : ["spotify"]

    // What Enter does on an emoji or symbol in the launcher: "type" it into the window you were
    // in (needs wtype), or "copy" it to the clipboard.
    readonly property string emojiAction: root._j.emojiAction === "copy" ? "copy" : "type"

    // The audio spectrum on the deck's now playing card and the bar (needs cava).
    readonly property bool visualizer: root._j.visualizer !== undefined ? !!root._j.visualizer : true

    // AirDrop through omdrop: a switch on the network page and a bar glyph while it's on. Off by default.
    readonly property bool airdrop: !!root._j.airdrop
    // A USB Wi-Fi adapter that brings AirDrop up when it's plugged in, by interface name: Gimbal
    // shows it starting, and gives the window it opens the length picked on the AirDrop page.
    readonly property string airdropAdapter: typeof root._j.airdropAdapter === "string" ? root._j.airdropAdapter : ""

    // The compositor config the keybinds page reads; empty picks mango's, or Hyprland's under it.
    readonly property string keybinds: root._expand(_pick("keybinds", "GIMBAL_KEYBINDS", ""))

    // GitHub accounts for the deck: "name", or { "user", "token" | "tokenFile" } to include
    // private work (a token must belong to that account).
    readonly property var github: {
        let v = root._j.github
        const env = Quickshell.env("GIMBAL_GITHUB")
        if (env) v = env.split(/[\s,]+/).filter(s => s.length > 0)
        if (!v) return []
        return (Array.isArray(v) ? v : [v])
            .map(a => typeof a === "string" ? { user: a } : a)
            .filter(a => a && a.user)
            .map(a => ({ user: String(a.user), token: String(a.token || ""), tokenFile: root._expand(String(a.tokenFile || "")) }))
    }

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
