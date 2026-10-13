pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// The compositor's key binds, grouped and described for the keybinds page. Read on demand.
QtObject {
    id: root

    readonly property string _cfg: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property bool hypr: Config.keybinds ? /hypr/.test(Config.keybinds)
                                                 : !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string path: Config.keybinds
        || root._cfg + (root.hypr ? "/hypr/hyprland.conf" : "/mango/config.conf")

    property var groups: []   // [{ name, binds: [{ keys: [..], label, detail }] }]
    property int total: 0

    function refresh() { _read.running = true }

    // The config with its sourced files inlined, so binds kept in other files show too.
    property Process _read: Process {
        command: ["sh", "-c",
            'inline() { [ -r "$1" ] || return; [ "$2" -gt 4 ] && return; '
            + 'while IFS= read -r l || [ -n "$l" ]; do '
            + 'case "$l" in [[:space:]]*source*=*|source*=*) '
            + 'p=$(printf %s "${l#*=}" | sed "s/^[[:space:]]*//; s/[[:space:]]*$//; s|^~|$HOME|"); '
            + 'case "$p" in /*) ;; *) p="$(dirname "$1")/$p" ;; esac; inline "$p" $(($2 + 1)) ;; '
            + '*) printf "%s\\n" "$l" ;; esac; done < "$1"; }; inline "$1" 0',
            "_", root.path]
        stdout: StdioCollector { onStreamFinished: root._parse(this.text) }
    }

    readonly property var _mods: ({ super: "Super", mod4: "Super", logo: "Super", win: "Super",
        shift: "Shift", ctrl: "Ctrl", control: "Ctrl", alt: "Alt", mod1: "Alt" })
    readonly property var _keys: ({
        left: "←", right: "→", up: "↑", down: "↓", return: "Enter", enter: "Enter", space: "Space",
        tab: "Tab", escape: "Esc", grave: "`", minus: "-", equal: "=", backslash: "\\", slash: "/",
        comma: ",", period: ".", semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]",
        page_up: "PgUp", page_down: "PgDn", prior: "PgUp", next: "PgDn", print: "Print", delete: "Del",
        btn_left: "Left drag", btn_right: "Right drag", btn_middle: "Middle drag",
        "mouse:272": "Left drag", "mouse:273": "Right drag", mouse_up: "Scroll ↑", mouse_down: "Scroll ↓",
        xf86audioraisevolume: "Vol +", xf86audiolowervolume: "Vol −", xf86audiomute: "Mute",
        xf86audiomicmute: "Mic mute", xf86audioplay: "Play", xf86audiopause: "Pause",
        xf86audionext: "Next", xf86audioprev: "Prev", xf86audiostop: "Stop",
        xf86monbrightnessup: "Bright +", xf86monbrightnessdown: "Bright −",
        xf86kbdbrightnessup: "Kbd +", xf86kbdbrightnessdown: "Kbd −"
    })
    function _key(k) {
        const v = root._keys[k.toLowerCase()]
        return v !== undefined ? v : k.length === 1 ? k.toUpperCase() : k.replace(/^XF86/, "")
    }

    // What an action does, in a few words. `a` is its argument string.
    readonly property var _dir: ({ left: "left", right: "right", up: "up", down: "down", l: "left", r: "right", u: "up", d: "down" })
    function _does(act, a) {
        const d = root._dir[a.toLowerCase()] || a
        switch (act) {
        case "focusdir": case "movefocus":         return "Focus " + d
        case "exchange_client": case "swapwindow": return "Swap " + d
        case "movewindow":           return "Move " + d
        case "killclient": case "killactive": return "Close window"
        case "togglefloating":       return "Float"
        case "togglefullscreen": case "fullscreen": return "Fullscreen"
        case "togglemaximizescreen": return "Maximize"
        case "toggleglobal": case "pin": return "Pin to every tag"
        case "centerwin": case "centerwindow": return "Center window"
        case "setmfact":             return a.indexOf("-") === 0 ? "Shrink main" : "Grow main"
        case "moveresize":           return a === "curresize" ? "Resize window" : "Move window"
        case "view": case "workspace": return /^[ex]?[+-]/.test(a) ? (a.indexOf("-") >= 0 ? "Previous" : "Next") + " tag" : "Tag " + a.split(",")[0]
        case "tag": case "movetoworkspace": case "movetoworkspacesilent": return "Send to tag " + a.split(",")[0]
        case "viewtoleft": case "viewtoleft_have_client":   return "Previous tag"
        case "viewtoright": case "viewtoright_have_client": return "Next tag"
        case "tagtoleft":            return "Send to previous tag"
        case "tagtoright":           return "Send to next tag"
        case "toggleoverview":       return "Overview"
        case "toggle_special_tag": case "togglespecialworkspace": return "Stash"
        case "swap_special":         return "Swap with stash"
        case "reload_config":        return "Reload config"
        case "quit": case "exit":    return "Quit"
        }
        const s = act.replace(/_/g, " ")
        return s.charAt(0).toUpperCase() + s.slice(1) + (a ? " " + a : "")
    }

    readonly property var _gimbal: ({ toggle: "Deck", launch: "Launcher", walls: "Wallpapers",
        rest: "Rest screen", deck: "Deck" })
    // A spawned command: its label, the rest as detail, and the group it belongs to.
    function _cmd(c) {
        const w = c.trim().match(/(?:[^\s"]+|"[^"]*")+/g) || []
        if (w[0] === "raise-or-run") w.splice(0, 2)
        const bin = (w[0] || "").split("/").pop(), rest = w.slice(1).join(" ")
        if (bin === "gimbal") {
            const s = root._gimbal[w[1]] && w.length === 2 ? root._gimbal[w[1]] : rest
            return { group: "Gimbal", label: s.charAt(0).toUpperCase() + s.slice(1), detail: "" }
        }
        if (/^(playerctl|wpctl|pamixer|pactl|brightnessctl|oledctl)$/.test(bin))
            return { group: "Media", label: bin + " " + rest, detail: "" }
        // A lone flag's value says which variant this is (a browser profile); several are noise.
        const flags = w.slice(1).filter(x => x.indexOf("-") === 0)
        const detail = w.slice(1).filter(x => x.indexOf("-") !== 0)
            .concat(flags.length === 1 && flags[0].indexOf("=") > 0 ? [flags[0].split("=")[1]] : [])
        return { group: "Apps", label: bin, detail: detail.join(" ").replace(/"/g, "") }
    }
    function _group(act) {
        if (/^(view|tag|workspace|movetoworkspace|viewto|tagto|toggleoverview|toggle_special|swap_special|togglespecial)/.test(act)) return "Tags"
        if (/^(reload|quit|exit|dpms|lock)/.test(act)) return "System"
        return "Windows"
    }

    function _parse(text) {
        const vars = {}, out = []
        for (let line of text.split("\n")) {
            line = line.replace(/\s+#.*$/, "").trim()
            if (!line || line[0] === "#") continue
            const v = /^\$(\w+)\s*=\s*(.*)$/.exec(line)
            if (v) { vars[v[1]] = v[2].trim(); continue }
            const m = /^(bind[a-z]*|mousebind|axisbind|gesturebind)\s*=\s*(.*)$/.exec(line)
            if (!m) continue
            const kw = m[1]
            let f = m[2].replace(/\$(\w+)/g, (_, n) => vars[n] !== undefined ? vars[n] : n).split(",").map(s => s.trim())
            let desc = ""
            if (root.hypr && kw.indexOf("bind") === 0 && kw.slice(4).indexOf("d") >= 0) desc = f.splice(2, 1)[0] || ""

            const mods = f[0].split(/[\s+_]+/).map(x => root._mods[x.toLowerCase()]).filter(x => x)
            let key, act, args
            if (kw === "gesturebind") {
                key = f[2] + "-finger " + (root._keys[f[1].toLowerCase()] || f[1])
                act = f[3]; args = f.slice(4).join(",")
            } else {
                key = kw === "axisbind" ? "Scroll " + (root._keys[f[1].toLowerCase()] || f[1]) : root._key(f[1] || "")
                act = (f[2] || "").toLowerCase(); args = f.slice(3).join(",")
            }

            let b
            if (/^(spawn|spawn_shell|exec)$/.test(act)) b = root._cmd(args)
            else b = { group: /^xf86/i.test(f[1] || "") ? "Media" : root._group(act), label: root._does(act, args), detail: "" }
            if (/^xf86/i.test(f[1] || "")) b.group = "Media"
            if (desc) { b.label = desc; b.detail = "" }
            out.push({ mods: mods, key: key, rawKey: (f[1] || "").toLowerCase(), act: act, args: args,
                       group: b.group, label: b.label, detail: b.detail })
        }
        root.total = out.length
        root.groups = root._grouped(root._fold(out))
    }

    // Runs of one action over the arrows or the digits fold into one line: "Super ←↑↓→  Focus".
    function _fold(list) {
        const res = []
        for (let i = 0; i < list.length;) {
            const b = list[i], arrows = ["left", "right", "up", "down"], digit = /^[0-9]$/.test(b.rawKey)
            let j = i + 1
            if (digit || arrows.indexOf(b.rawKey) >= 0) {
                while (j < list.length && list[j].act === b.act && list[j].mods.join() === b.mods.join()
                       && (digit ? /^[0-9]$/.test(list[j].rawKey) : arrows.indexOf(list[j].rawKey) >= 0)) j++
            }
            if (j - i >= 3) {
                const run = list.slice(i, j)
                const keys = digit ? run[0].rawKey + "–" + run[run.length - 1].rawKey
                                   : ["left", "up", "down", "right"].filter(a => run.some(r => r.rawKey === a)).map(a => root._keys[a]).join("")
                const label = digit ? root._does(b.act, keys) : root._does(b.act, "").replace(/\s+$/, "")
                res.push({ keys: b.mods.concat([keys]), group: b.group, label: label, detail: "" })
            } else {
                for (let k = i; k < j; k++) res.push({ keys: list[k].mods.concat([list[k].key]), group: list[k].group, label: list[k].label, detail: list[k].detail })
            }
            i = j
        }
        // The same keys bound twice (one locked, one not) show once.
        const seen = {}
        return res.filter(r => { const k = r.keys.join("+") + r.label; if (seen[k]) return false; seen[k] = true; return true })
    }

    readonly property var _order: ["Apps", "Gimbal", "Windows", "Tags", "Media", "System"]
    function _grouped(list) {
        return root._order.map(n => ({ name: n, binds: list.filter(b => b.group === n) })).filter(g => g.binds.length > 0)
    }
}
