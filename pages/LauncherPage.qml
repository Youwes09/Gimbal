import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    readonly property real uiScale: 1.12
    function f(px) { return Sh.fs(px * root.uiScale) }

    readonly property int sp1: f(4)
    readonly property int sp2: f(8)
    readonly property int sp3: f(12)
    readonly property int sp4: f(16)
    readonly property int sp5: f(20)

    readonly property int rSm: f(8)
    readonly property int rMd: f(12)
    readonly property int rLg: f(16)

    // Same language as the deck (DeckUi): near-black panel, a hairline edge a touch brighter
    // than the deck's so it still pops over windows, the inset top highlight, neutral
    // selection with an accent ring.
    readonly property color cPanel:  DeckUi.card
    readonly property color cRim:    Qt.rgba(1, 1, 1, 0.13)
    readonly property color cSheen:  DeckUi.sheen
    readonly property color cShadow: Qt.rgba(0, 0, 0, 0.8)
    readonly property real  wRim:    1
    readonly property color cSel:    DeckUi.sel
    readonly property color cSelRim: DeckUi.selRim
    readonly property color cHover:  DeckUi.hover
    readonly property color cLine:   DeckUi.line

    readonly property int tInput:   18
    readonly property int tRow:     16
    readonly property int tHead:    15
    readonly property int tBody:    13
    readonly property int tMeta:    12
    readonly property int tCaption: 12

    property string query: ""
    property int selected: 0

    property bool inspectOpen: false
    property bool inspectActive: false
    property real iT: 0

    function _shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    readonly property var _parsed: {
        const raw = root.query
        const s = raw.replace(/^\s+/, "")
        if (s.startsWith(">")) return { m: "run",       q: s.slice(1).replace(/^\s+/, "") }
        if (s.startsWith("=")) return { m: "calc",      q: s.slice(1).replace(/^\s+/, "") }
        if (s.startsWith(";")) return { m: "clipboard", q: s.slice(1).replace(/^\s+/, "") }
        if (s.startsWith("/") || s.startsWith("~")) return { m: "files", q: s }
        return { m: "apps", q: raw.trim() }
    }
    readonly property string mode: root._parsed.m
    readonly property string q:    root._parsed.q

    readonly property bool expanded: root.query.length > 0 || root.results.length > 0

    readonly property var _apps: [...DesktopEntries.applications.values]
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""))

    function _score(app, q) {
        const n = (app.name || "").toLowerCase()
        if (n === q) return 0
        if (n.startsWith(q)) return 1
        if ((" " + n).includes(" " + q)) return 2
        if (n.includes(q)) return 3
        const g = (app.genericName || "").toLowerCase()
        if (g.includes(q)) return 4
        return null
    }
    function _appRow(a) {
        return {
            id:       a.id,
            title:    a.name || a.id,
            path:     a.genericName || a.comment || "",
            kind:     "app",
            iconPath: Quickshell.iconPath(a.icon, true),
            body:     (a.comment || a.genericName || ""),
            exec:     (a.command || []).join(" "),
            cats:     (a.categories || []).join(", "),
            run:      () => {
                Frecency.bump("app:" + a.id)
                const go = () => {
                    if (!a.runInTerminal && a.command && a.command.length) Compositor.spawn(a.command)
                    else a.execute()
                    Launches.begin(a.name, Quickshell.iconPath(a.icon, true),
                                   [a.startupClass, a.id, a.name])
                }
                if (Config.raiseRunning)
                    Compositor.raiseOrRun([a.startupClass, a.id, a.name], go)
                else go()
            },
            runNew:   () => {
                Frecency.bump("app:" + a.id)
                if (!a.runInTerminal && a.command && a.command.length) Compositor.spawn(a.command)
                else a.execute()
                Launches.begin(a.name, Quickshell.iconPath(a.icon, true),
                               [a.startupClass, a.id, a.name])
            },
            kill:     () => {
                Compositor.killApp([a.startupClass, a.id, a.name], (a.command && a.command[0]) || "")
                Launches.killed(a.name)
            }
        }
    }
    readonly property var appResults: {
        const _ = Frecency.rev
        const q = root.q.toLowerCase()
        if (q.length === 0) return []
        return root._apps.map(a => ({ a: a, s: root._score(a, q) }))
            .filter(x => x.s !== null)
            .map(x => ({ a: x.a, s: x.s - Math.min(0.9, Frecency.score("app:" + x.a.id) * 0.12) }))
            .sort((x, y) => x.s - y.s)
            .map(x => root._appRow(x.a))
    }

    function _dirDefault(path) {
        const e = Frecency.score("diropen|editor|" + path)
        const f = Frecency.score("diropen|files|" + path)
        const t = Frecency.score("diropen|terminal|" + path)
        const m = Math.max(e, f, t)
        if (m > 0) return e === m ? "editor" : (f === m ? "files" : "terminal")
        return Config.dirOpen
    }
    function _fileRow(x) {
        const key = (x.isDir ? "dir:" : "file:") + x.path
        const p = x.path
        const learn = act => { if (x.isDir) Frecency.bump("diropen|" + act + "|" + p) }
        const asEditor  = () => { Frecency.bump(key); learn("editor");   Places.openEditor(p, x.isDir) }
        const asManager = () => { Frecency.bump(key); learn("files");    Places.openManager(x.isDir ? p : Places._parent(p)) }
        const asTerm    = () => { Frecency.bump(key); learn("terminal"); Places.openTerminal(p, x.isDir) }
        const asSmart   = () => { Frecency.bump(key); Places.openSmart(p) }
        return {
            id:     key,
            title:  x.name,
            path:   x.dir,
            kind:   x.isDir ? "dir" : "file",
            iconPath: "",
            body:   p,
            isDir:  x.isDir,

            run: () => {
                if (!x.isDir) { asEditor(); return }
                const d = root._dirDefault(p)
                d === "files" ? asManager() : d === "terminal" ? asTerm()
                    : d === "editor" ? asEditor() : asSmart()
            },
            runEditor:  asEditor,
            runManager: asManager,
            runTerminal: asTerm,
            runAlt:     asTerm
        }
    }
    readonly property var fileResults: {
        const _ = Frecency.rev
        const L = Places.list
        const q = root.q.replace(/^[~/]\s*/, "").trim().toLowerCase()
        if (q.length === 0) return []
        const out = []
        for (const x of L) {
            const n = x.name.toLowerCase()
            let s = n === q ? 0 : n.startsWith(q) ? 1 : n.includes(q) ? 2
                  : x.path.toLowerCase().includes(q) ? 3.5 : null
            if (s === null) continue
            s -= Math.min(0.9, Frecency.score((x.isDir ? "dir:" : "file:") + x.path) * 0.15)
            out.push({ x: x, s: s })
        }
        return out.sort((a, b) => a.s - b.s).slice(0, 50).map(o => root._fileRow(o.x))
    }

    function _calc(expr) {
        if (!/^[-+*/%^.()eE0-9\s]+$/.test(expr) || expr.trim().length === 0) return null
        const toks = expr.match(/\d*\.?\d+(?:e[-+]?\d+)?|[-+*/%^()]/gi)
        if (!toks) return null
        const prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "^": 3 }
        const out = [], ops = []
        let prev = null
        for (let t of toks) {
            if (/^[\d.]/.test(t) || /e/i.test(t)) { out.push(parseFloat(t)); prev = "n" }
            else if (t === "(") { ops.push(t); prev = "(" }
            else if (t === ")") {
                while (ops.length && ops[ops.length - 1] !== "(") out.push(ops.pop())
                if (!ops.length) return null
                ops.pop(); prev = "n"
            } else {

                if (t === "-" && (prev === null || prev === "(" || prev === "op")) { out.push(0) }
                const right = t === "^"
                while (ops.length && ops[ops.length - 1] !== "("
                       && (right ? prec[ops[ops.length - 1]] > prec[t]
                                 : prec[ops[ops.length - 1]] >= prec[t]))
                    out.push(ops.pop())
                ops.push(t); prev = "op"
            }
        }
        while (ops.length) { const o = ops.pop(); if (o === "(") return null; out.push(o) }
        const st = []
        for (const x of out) {
            if (typeof x === "number") { st.push(x); continue }
            const b = st.pop(), a = st.pop()
            if (a === undefined || b === undefined) return null
            st.push(x === "+" ? a + b : x === "-" ? a - b : x === "*" ? a * b
                  : x === "/" ? a / b : x === "%" ? a % b : Math.pow(a, b))
        }
        const v = st.pop()
        return (st.length === 0 && typeof v === "number" && isFinite(v)) ? v : null
    }
    readonly property var calcResults: {
        const v = root._calc(root.q)
        if (v === null) return []
        const out = "" + (Math.round(v * 1e10) / 1e10)
        return [{
            id: "calc", title: out, path: root.q.trim() + "  =", kind: "calc",
            iconPath: "", body: out,
            run: () => Quickshell.execDetached(["sh", "-c",
                "printf %s " + root._shq(out) + " | wl-copy"])
        }]
    }

    readonly property var runResults: {
        const c = root.q.trim()
        if (c.length === 0) return []
        return [{
            id: "run:" + c, title: c, path: "run command", kind: "run",
            iconPath: "", body: c,
            run: () => { Frecency.bump("cmd:" + c); Quickshell.execDetached(["sh", "-c", c]) }
        }]
    }

    readonly property var _capActions: [
        { id: "cap:shot-region", title: "Screenshot — region", hint: "select an area",
          glyph: Sh.icMonitor, act: () => Capture.shot("region"),
          keys: ["screenshot", "screen shot", "snip", "region", "capture", "grab", "printscreen", "print screen"] },
        { id: "cap:shot-full", title: "Screenshot — full screen", hint: "whole display",
          glyph: Sh.icMonitor, act: () => Capture.shot("full"),
          keys: ["screenshot full", "fullscreen", "full screen", "screenshot screen", "capture screen"] },
        { id: "cap:rec", title: Capture.recording ? "Stop recording" : "Record — full screen",
          hint: Capture.recording ? "finish and save" : "screen recording",
          glyph: Capture.recording ? Sh.icPause : Sh.icPlay, act: () => Capture.recToggle(),
          keys: ["record", "screen record", "recording", "screencast", "capture video"] },
        { id: "cap:rec-region", title: "Record — region", hint: "record an area",
          glyph: Sh.icPlay, act: () => Capture.recStart("region"), keys: ["record region"] },
        { id: "cap:last", title: "Open last screenshot", hint: "default image viewer",
          glyph: Sh.icFile, act: () => Capture.openLast(), need: () => Capture.lastShot.length > 0,
          keys: ["screenshots", "last screenshot", "captures", "last capture"] }
    ]
    function _capRow(a) {
        return {
            id: a.id, title: a.title, path: a.hint || "", kind: "action",
            iconPath: "", iconGlyph: a.glyph, body: "",
            run: a.act
        }
    }
    readonly property var captureResults: {
        const _ = Capture.recording
        const q = root.q.toLowerCase().trim()
        if (q.length < 2) return []
        const out = []
        for (const a of root._capActions) {
            if (a.need && !a.need()) continue
            let hit = false
            for (const k of a.keys) {
                if (k.indexOf(q) >= 0 || q.indexOf(k) === 0) { hit = true; break }
            }
            if (hit) out.push(root._capRow(a))
        }
        return out
    }

    readonly property var _dndActions: [
        { id: "dnd:toggle",
          title: Notifications.dnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb",
          hint: Notifications.dnd ? "resume notifications" : "silence notifications",
          glyph: Notifications.dnd ? Sh.icBell : Sh.icBellOff, act: () => Notifications.toggleDnd(),
          keys: ["dnd", "do not disturb", "silence", "silence notifications",
                 "mute notifications", "quiet mode", "focus mode"] }
    ]
    readonly property var dndResults: {
        const _ = Notifications.dnd
        const q = root.q.toLowerCase().trim()
        if (q.length < 2) return []
        const out = []
        for (const a of root._dndActions) {
            let hit = false
            for (const k of a.keys) {
                if (k.indexOf(q) >= 0 || q.indexOf(k) === 0) { hit = true; break }
            }
            if (hit) out.push(root._capRow(a))
        }
        return out
    }

    ClipboardList {
        id: clipboard
        filterText: root.mode === "clipboard" ? root.q : ""
        active: Sh.launcherShown && root.mode === "clipboard"
    }

    FileInspect { id: fileInspect }
    readonly property bool _curIsFile: root.current
        && (root.current.kind === "file" || root.current.kind === "dir")
    readonly property var clipResults: clipboard.entries.map(e => ({
        id:       e.id,
        title:    e.kind === "image" ? "Image" : (e.preview.split("\n")[0].slice(0, 120) || "(empty)"),
        path:     e.kind === "image" && e.meta ? (e.meta.fmt.toUpperCase() + "  ·  " + e.meta.w + "×" + e.meta.h)
                                               : root._kindLabel(e.kind),
        kind:     e.kind,
        iconPath: "",
        body:     e.preview,
        meta:     e.meta,
        run:      () => clipboard.copyEntry(e.id)
    }))

    readonly property var results:
          root.mode === "clipboard" ? root.clipResults
        : root.mode === "files"     ? root.fileResults
        : root.mode === "calc"      ? root.calcResults
        : root.mode === "run"       ? root.runResults
        : root.captureResults.concat(root.dndResults).concat(root.appResults)
    onResultsChanged: { selected = 0; inspectOpen = false }
    readonly property var current: results.length > 0
        ? results[Math.max(0, Math.min(selected, results.length - 1))] : null

    onCurrentChanged: root._loadInspect()
    function _loadInspect() {
        if (!root.inspectOpen || !root.current) return
        const c = root.current
        if (root.mode === "clipboard") {
            if (c.kind === "image") clipboard.showImage(c.id)
            else clipboard.decodeText(c.id)
        } else if (c.kind === "file" || c.kind === "dir") {
            fileInspect.load(c.body)
        }
    }

    function _glyph(kind) {
        return kind === "term"  ? Sh.icTerm
             : kind === "run"   ? Sh.icTerm
             : kind === "calc"  ? Sh.icCorner
             : kind === "dir"   ? Sh.icFolder
             : kind === "file"  ? Sh.icFile
             : kind === "app"   ? Sh.icApp
             : kind === "link"  ? Sh.icSearch
             : kind === "image" ? Sh.icFile
             : kind === "color" ? Sh.icDroplet
             : Sh.icFile
    }
    function _kindLabel(kind) {
        return kind === "app" ? "App" : kind === "dir" ? "Folder" : kind === "file" ? "File"
             : kind === "run" ? "Command" : kind === "calc" ? "Result"
             : kind === "action" ? "Action"
             : kind === "link" ? "Link" : kind === "image" ? "Image"
             : kind === "color" ? "Color" : "Text"
    }

    function _rgb(hex) {
        let h = hex.replace("#", "")
        if (h.length === 3) h = h.split("").map(c => c + c).join("")
        return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]
    }
    function _hsl(hex) {
        const [r, g, b] = _rgb(hex).map(v => v / 255)
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn
        let hh = 0
        if (d !== 0) {
            if (mx === r) hh = ((g - b) / d) % 6
            else if (mx === g) hh = (b - r) / d + 2
            else hh = (r - g) / d + 4
        }
        hh = Math.round(hh * 60); if (hh < 0) hh += 360
        const l = (mx + mn) / 2
        const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
        return hh + "°  " + Math.round(s * 100) + "%  " + Math.round(l * 100) + "%"
    }

    readonly property var inspectRows: {
        const c = root.current
        if (!c) return []
        if (c.kind === "file" || c.kind === "dir") {
            return [["Path", c.body]].concat(fileInspect.rows)
        }
        if (c.kind === "image") {
            const m = c.meta
            return [["Type", m ? m.fmt.toUpperCase() + " image" : "Image"],
                    ["Size", m ? m.size : "—"],
                    ["Dimensions", m ? m.w + " × " + m.h + " px" : "—"]]
        }
        if (c.kind === "color") {
            return [["Hex", c.title.toUpperCase()],
                    ["RGB", root._rgb(c.title).join(", ")],
                    ["HSL", root._hsl(c.title)]]
        }
        if (c.kind === "app") {
            const rows = [["Command", c.exec || "—"]]
            if (c.cats) rows.push(["Categories", c.cats])
            if (c.path) rows.push(["Role", c.path])
            return rows
        }
        const t = clipboard.fullText || c.body || ""
        return [["Type", c.kind === "link" ? "Link" : "Text"],
                ["Characters", "" + t.length],
                ["Words", "" + (t.trim() ? t.trim().split(/\s+/).length : 0)],
                ["Lines", "" + t.split("\n").length]]
    }
    readonly property string inspectText: {
        const c = root.current
        if (!c) return ""
        if (c.kind === "file" || c.kind === "dir") return fileInspect.text
        if (c.kind === "app") return c.body || ""
        return clipboard.fullText || c.body || ""
    }

    function _onText(t) { root.query = t }

    function activateWith(mode) {
        const c = root.current
        if (!c) return
        if (mode === "editor"   && c.runEditor)   c.runEditor()
        else if (mode === "manager"  && c.runManager)  c.runManager()
        else if (mode === "terminal" && c.runTerminal) c.runTerminal()
        else if (mode === "terminal" && c.runAlt)      c.runAlt()
        else if (mode === "new"      && c.runNew)      c.runNew()
        else c.run()
        Sh.closeLauncher()
    }
    function activate()    { root.activateWith("") }
    function _enter(ev) {
        ev.accepted = true
        if (ev.isAutoRepeat || root._fired) return
        root._fired = true
        Qt.callLater(() => root._fired = false)
        const k = root.current ? root.current.kind : ""
        if (ev.modifiers & Qt.ShiftModifier)        root.activateWith(k === "app" ? "new" : "terminal")
        else if (ev.modifiers & Qt.ControlModifier) root.activateWith("editor")
        else if (ev.modifiers & Qt.AltModifier)     root.activateWith("manager")
        else root.activate()
    }
    property bool _fired: false
    readonly property var _noInspect: ["run", "calc", "action"]
    function toggleInspect() {
        if (!root.current || root._noInspect.indexOf(root.current.kind) >= 0) return
        root.inspectOpen = !root.inspectOpen
    }
    function reset() {
        input.clear()
        query = ""
        selected = 0
        inspectOpen = false
        Places.rescan()
        input.forceActiveFocus()
    }

    onInspectOpenChanged: {
        if (root.inspectOpen) { root.inspectActive = true; root._loadInspect(); iOpen.restart() }
        else iClose.restart()
    }
    Anim { id: iOpen; target: root; property: "iT"; to: 1; duration: Motion.slow }
    SequentialAnimation {
        id: iClose
        AnimOut { target: root; property: "iT"; to: 0 }
        ScriptAction { script: root.inspectActive = false }
    }

    Connections {
        target: Sh
        function onLauncherShownChanged() { if (Sh.launcherShown) root.reset() }
    }
    Component.onCompleted: if (Sh.launcherShown) root.reset()

    Item {
        id: panelWrap
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.26)

        readonly property real barH: root.f(58)
        readonly property real resultsMax: Math.min(root.f(460), root.height * 0.5)

        readonly property real resultsH: root.results.length === 0 ? 0
            : Math.min(panelWrap.resultsMax,
                       Math.max(root.f(58), list.contentHeight + root.sp2 * 2))

        width: Math.min(root.f(800), root.width * 0.54)
        height: panelWrap.barH + (root.expanded ? panelWrap.resultsH : 0)
        Behavior on height { Anim {} }

        opacity: root.inspectActive ? 1 - 0.72 * root.iT : 1
        scale:   root.inspectActive ? 1 - 0.02 * root.iT : 1
        // Flattened only while it fades behind the inspect card, so the fade stays clean.
        layer.enabled: root.inspectActive

        // Analytic shadow: follows the height animation without re-rendering anything.
        RectangularShadow {
            anchors.fill: panel
            radius: root.rLg
            blur: root.f(48)
            offset.y: root.f(14)
            spread: root.f(2)
            color: root.cShadow
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: root.rLg
            color: root.cPanel
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: root.wRim
                border.color: root.cRim
                z: 10
            }
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.rLg }
                anchors.topMargin: 1
                height: 1
                color: root.cSheen
                z: 10
            }

            Item {
                id: bar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: panelWrap.barH

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.sp4
                    anchors.rightMargin: root.sp4
                    spacing: root.sp3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sh.icSearch
                        color: DeckUi.dim
                        font.family: Sh.iconFont
                        font.pixelSize: root.f(19)
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - root.f(19) - root.sp3 * 2
                               - (modeTag.visible ? modeTag.width + root.sp3 : 0)
                        height: input.implicitHeight

                        TextInput {
                            id: input
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: root._onText(text)
                            color: DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: root.f(root.tInput)
                            selectByMouse: true
                            clip: true
                            cursorDelegate: Rectangle { width: 2; color: DeckUi.accent; visible: input.cursorVisible }
                            Keys.onEscapePressed: {
                                if (root.inspectOpen) { root.inspectOpen = false; return }
                                if (root.query.length > 0) input.clear()
                                else Sh.closeLauncher()
                            }
                            Keys.onPressed: (ev) => {
                                if (ev.key === Qt.Key_Tab || ev.key === Qt.Key_Backtab) {
                                    root.toggleInspect()
                                    ev.accepted = true
                                    return
                                }
                                if (ev.key === Qt.Key_Delete && root.current && root.current.kind === "app"
                                        && root.current.kill
                                        && ((ev.modifiers & Qt.ShiftModifier)
                                            || input.cursorPosition === input.text.length)) {
                                    root.current.kill()
                                    ev.accepted = true
                                    return
                                }
                            }
                            Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                            Keys.onUpPressed:   root.selected = Math.max(0, root.selected - 1)
                            Keys.onReturnPressed: (ev) => root._enter(ev)
                            Keys.onEnterPressed:  (ev) => root._enter(ev)
                        }
                        ScrambleText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: root.query.length === 0
                            gateOnReveal: false
                            show: root.query.length === 0 && Sh.launcherShown
                            span: 460
                            content: "Search"
                            color: DeckUi.dim
                            font.family: DeckUi.sans
                            font.pixelSize: root.f(root.tInput)
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: modeTag
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.mode !== "apps"
                        width: tagText.implicitWidth + root.sp3
                        height: root.f(22)
                        radius: DeckUi.badgeRadius
                        color: DeckUi.graphite
                        border.width: 1
                        border.color: DeckUi.line
                        ScrambleText {
                            id: tagText
                            anchors.centerIn: parent
                            gateOnReveal: false
                            show: root.mode !== "apps"
                            span: 380
                            hold: 32
                            content: ({ run: "Command", calc: "Calc", files: "Files",
                                        clipboard: "Clipboard" })[root.mode] || ""
                            color: DeckUi.text
                            font.family: DeckUi.mono
                            font.pixelSize: root.f(root.tCaption)
                        }
                        Behavior on width { Anim { duration: Motion.fast } }
                        Behavior on opacity { Anim { duration: Motion.fast } }
                        opacity: visible ? 1 : 0
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: root.cLine
                    opacity: root.results.length > 0 ? 1 : 0
                    Behavior on opacity { Anim { duration: Motion.fast } }
                }
            }

            Item {
                anchors { top: bar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                visible: root.results.length > 0
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: root.sp2
                    model: root.results
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    populate: Transition {
                        id: pop
                        SequentialAnimation {
                            PauseAnimation { duration: Math.min(6, pop.ViewTransition.index) * 24 }
                            ParallelAnimation {
                                Anim { property: "opacity"; from: 0; to: 1; duration: Motion.fast }
                                Anim { property: "scale"; from: 0.97; to: 1 }
                            }
                        }
                    }
                    displaced: Transition {
                        Anim { property: "y" }
                    }

                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 150
                    highlightResizeDuration: 0
                    highlight: Rectangle {
                        z: 0
                        width: list.width - root.sp1 * 2
                        x: root.sp1
                        radius: root.rSm
                        color: root.cSel
                        border.width: 1
                        border.color: root.cSelRim
                        opacity: root.results.length > 0 ? 1 : 0
                        Behavior on opacity { Anim { duration: Motion.fast } }
                    }

                    delegate: Item {
                        id: rowItem
                        width: list.width
                        height: root.f(58)
                        readonly property bool sel: index === root.selected
                        readonly property bool isImg: modelData.kind === "image"

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: root.sp1
                            anchors.rightMargin: root.sp1
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: root.rSm
                            color: (!rowItem.sel && rowMouse.containsMouse) ? root.cHover : "transparent"
                            Behavior on color { CAnim {} }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.sp4
                            anchors.rightMargin: root.sp3
                            spacing: root.sp3

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.f(34); height: root.f(34)
                                scale: rowItem.sel ? 1.04 : 1
                                Behavior on scale {
                                    Anim { duration: Motion.fast }
                                }

                                // Every icon and glyph sits on the same tile (as in the deck's lists);
                                // images and colour swatches fill it instead.
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !rowItem.isImg && modelData.kind !== "color"
                                    radius: root.rSm
                                    color: DeckUi.graphite
                                    border.width: 1
                                    border.color: DeckUi.line
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    width: root.f(22); height: width
                                    visible: modelData.iconPath && modelData.iconPath.length > 0
                                    icon: modelData.iconPath || ""
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    visible: rowItem.isImg
                                    radius: root.f(7)
                                    color: "transparent"
                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        cache: false
                                        asynchronous: true
                                        sourceSize.width: root.f(68); sourceSize.height: root.f(68)
                                        source: rowItem.isImg ? clipboard.thumbUrl(modelData.id) : ""
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.f(7)
                                    visible: modelData.kind === "color"
                                    color: modelData.kind === "color" ? modelData.title : "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !(modelData.iconPath && modelData.iconPath.length > 0)
                                             && !rowItem.isImg && modelData.kind !== "color"
                                    text: modelData.iconGlyph || root._glyph(modelData.kind)
                                    color: rowItem.sel ? DeckUi.text : DeckUi.dim
                                    font.family: Sh.iconFont
                                    font.pixelSize: root.f(16)
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - root.f(34) - root.sp3 * 2 - inspectHint.width
                                spacing: 2
                                Text {
                                    text: modelData.title
                                    color: DeckUi.text
                                    font.family: DeckUi.sans
                                    font.pixelSize: root.f(root.tRow)
                                    font.weight: rowItem.sel ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    visible: modelData.path.length > 0
                                    text: modelData.path
                                    color: DeckUi.dim
                                    font.family: DeckUi.sans
                                    font.pixelSize: root.f(root.tMeta)
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Text {
                                id: inspectHint
                                anchors.verticalCenter: parent.verticalCenter
                                visible: rowItem.sel
                                readonly property string _dd: modelData.kind === "dir"
                                    ? ({ smart: "open", editor: "code", files: "files",
                                         terminal: "term" })[root._dirDefault(modelData.body)] || "open"
                                    : ""
                                text: modelData.kind === "dir"
                                        ? ("⏎ " + _dd + " · ⌃ code · ⌥ files · ⇧ term")
                                     : modelData.kind === "file"
                                        ? "⏎ open · ⌥ reveal · ⇧ term"
                                     : modelData.kind === "calc" ? "⏎ copy"
                                     : modelData.kind === "run"  ? "⏎ run"
                                     : "Tab"
                                color: DeckUi.faint
                                font.family: DeckUi.mono
                                font.pixelSize: root.f(root.tCaption)
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.inspectActive
                            onEntered: root.selected = index
                            onClicked: { root.selected = index; root.activate() }
                            onDoubleClicked: { root.selected = index; root.toggleInspect() }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: root.mode === "clipboard" ? "Clipboard is empty" : "No results"
                    color: DeckUi.dim
                    font.family: DeckUi.sans
                    font.pixelSize: root.f(root.tBody)
                }
            }
        }
    }

    Rectangle {
        id: legend
        anchors.horizontalCenter: panelWrap.horizontalCenter
        anchors.top: panelWrap.bottom
        anchors.topMargin: root.sp3
        width: legendText.implicitWidth + root.sp4
        height: root.f(30)
        radius: root.rSm
        color: root.cPanel
        border.width: 1
        border.color: root.cRim
        opacity: (!root.expanded && !root.inspectActive) ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { Anim {} }

        ScrambleText {
            id: legendText
            anchors.centerIn: parent
            gateOnReveal: false
            show: legend.opacity > 0.5 && Sh.launcherShown
            span: 560
            content: "›  run      =  calc      /  files      ;  clipboard"
            color: DeckUi.faint
            font.family: DeckUi.mono
            font.pixelSize: root.f(root.tCaption)
            font.letterSpacing: 0.5
        }
    }

    Item {
        id: inspectLayer
        anchors.fill: parent
        visible: root.inspectActive
        z: 10

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(DeckUi.canvas, 0.55 * root.iT)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.inspectOpen = false
            }
        }

        readonly property var _c: root.current

        readonly property string _fk: root._curIsFile ? fileInspect.kind : ""

        readonly property bool _fkSvg: inspectLayer._fk === "image" && inspectLayer._c
            && /\.svgz?$/i.test(inspectLayer._c.body || "")

        readonly property bool _hasPreview:
              (_c && (_c.kind === "image" || _c.kind === "color" || _c.kind === "app"))
            || _fk === "image" || _fk === "video" || _fk === "text"
            || (_c && !root._curIsFile
                   && _c.kind !== "image" && _c.kind !== "color" && _c.kind !== "app")
        readonly property real imgAR: (_c && _c.meta && _c.meta.h > 0) ? _c.meta.w / _c.meta.h : 16 / 9
        readonly property real cardW: {
            if (!_c) return root.f(560)
            if (_c.kind === "image" || _fk === "image" || _fk === "video")
                return Math.min(root.f(1100), root.width * 0.74)
            if (_c.kind === "app")   return Math.min(root.f(460), root.width * 0.34)
            if (_c.kind === "color") return Math.min(root.f(520), root.width * 0.4)
            if (root._curIsFile && _fk !== "text") return Math.min(root.f(560), root.width * 0.42)
            return Math.min(root.f(760), root.width * 0.52)
        }
        readonly property real bodyH: {
            if (!_c) return root.f(300)
            if (_c.kind === "image") return Math.min(root.height * 0.72, (cardW - root.sp5 * 2) / imgAR)
            if (_fk === "image" || _fk === "video") return Math.min(root.f(560), root.height * 0.62)
            if (_c.kind === "color") return root.f(260)
            if (_c.kind === "app")   return root.f(300)
            if (root._curIsFile && _fk !== "text") return root.f(20)
            return Math.min(root.f(460), root.height * 0.52)
        }
        readonly property real metaH: root.inspectRows.length * root.f(28) + root.sp4 + 1
        readonly property real cardH: bodyH + root.sp5 * 2 + metaH

        Item {
            id: card
            anchors.centerIn: parent
            width: inspectLayer.cardW
            height: inspectLayer.cardH
            opacity: root.iT
            scale: 0.9 + 0.1 * root.iT
            Behavior on width  { Anim {} }
            Behavior on height { Anim {} }

            MouseArea { anchors.fill: parent; hoverEnabled: true }

            RectangularShadow {
                anchors.fill: parent
                radius: root.rLg
                blur: root.f(48)
                offset.y: root.f(16)
                spread: root.f(2)
                color: root.cShadow
            }
            Rectangle {
                anchors.fill: parent
                radius: root.rLg
                color: root.cPanel
                border.width: root.wRim
                border.color: root.cRim
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.rLg }
                    anchors.topMargin: 1
                    height: 1
                    color: root.cSheen
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.sp5
                spacing: root.sp3

                Item {
                    id: bodyBox
                    width: parent.width
                    visible: inspectLayer._hasPreview
                    height: visible ? inspectLayer.bodyH : 0

                    ClippingRectangle {
                        anchors.centerIn: parent
                        visible: inspectLayer._c && inspectLayer._c.kind === "image"
                        width:  Math.min(parent.width, parent.height * inspectLayer.imgAR)
                        height: Math.min(parent.height, parent.width / inspectLayer.imgAR)
                        radius: root.rMd
                        color: "transparent"
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            source: clipboard.previewUrl
                        }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        visible: inspectLayer._fk === "image"
                        radius: root.rMd
                        color: "transparent"
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            visible: !inspectLayer._fkSvg
                            source: inspectLayer._fk === "image" && !inspectLayer._fkSvg
                                    ? "file://" + inspectLayer._c.body : ""
                        }
                        AppIcon {
                            anchors.fill: parent
                            visible: inspectLayer._fkSvg
                            icon: inspectLayer._fkSvg ? ("file://" + inspectLayer._c.body) : ""
                        }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        visible: inspectLayer._fk === "video"
                        radius: root.rMd
                        color: "black"
                        Loader {
                            anchors.fill: parent
                            active: inspectLayer._fk === "video" && root.inspectActive
                            source: "WallpaperVideoPool.qml"
                            onLoaded: {
                                item.source = Qt.binding(() => inspectLayer._fk === "video"
                                    ? inspectLayer._c.body : "")
                                item.playing = Qt.binding(() => root.inspectActive)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: inspectLayer._c && inspectLayer._c.kind === "color"
                        radius: root.rMd
                        color: inspectLayer._c && inspectLayer._c.kind === "color" ? inspectLayer._c.title : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: root.sp3
                        visible: inspectLayer._c && inspectLayer._c.kind === "app"

                        AppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property real d: Math.min(inspectLayer.bodyH - root.f(72), root.f(148))
                            width: d; height: d
                            icon: inspectLayer._c && inspectLayer._c.kind === "app" ? (inspectLayer._c.iconPath || "") : ""
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: inspectLayer._c ? inspectLayer._c.title : ""
                            color: DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: root.f(root.tHead)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: inspectLayer._c && inspectLayer._c.body.length > 0
                            width: parent.width * 0.8
                            horizontalAlignment: Text.AlignHCenter
                            text: inspectLayer._c ? inspectLayer._c.body : ""
                            color: DeckUi.dim
                            font.family: DeckUi.sans
                            font.pixelSize: root.f(root.tMeta)
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    Flickable {
                        id: bodyFlick
                        anchors.fill: parent
                        visible: root._curIsFile ? (inspectLayer._fk === "text")
                               : (inspectLayer._c && inspectLayer._c.kind !== "image"
                                  && inspectLayer._c.kind !== "color" && inspectLayer._c.kind !== "app")
                        contentWidth: width
                        contentHeight: inspectBody.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        WheelHandler {
                            onWheel: (e) => {
                                const max = Math.max(0, bodyFlick.contentHeight - bodyFlick.height)
                                bodyFlick.contentY = Math.max(0, Math.min(max,
                                    bodyFlick.contentY - e.angleDelta.y))
                            }
                        }

                        Text {
                            id: inspectBody
                            width: parent.width
                            text: root.inspectText.length > 0 ? root.inspectText : "No content"
                            textFormat: Text.PlainText
                            color: DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: root.f(root.tBody)
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.cLine }

                Column {
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: root.inspectRows
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: root.f(28)
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[0]
                                color: DeckUi.dim
                                font.family: DeckUi.sans
                                font.pixelSize: root.f(root.tMeta)
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.64
                                horizontalAlignment: Text.AlignRight
                                text: modelData[1]
                                color: DeckUi.text
                                font.family: DeckUi.sans
                                font.pixelSize: root.f(root.tMeta)
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }
        }
    }
}
