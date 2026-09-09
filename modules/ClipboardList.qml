import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string filterText: ""
    property bool   active: false
    property var    rawLines: []

    function refresh() { listProc.exec(["cliphist", "list"]) }
    Component.onCompleted: { mkdirProc.exec(["mkdir", "-p", _thumbDir]); refresh() }
    onActiveChanged: if (active) refresh()

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: root.rawLines = this.text.split("\n").filter(l => l.length > 0)
        }
    }

    function _parse(line) {
        const tab = line.indexOf("\t")
        return tab === -1 ? { id: line, preview: line }
                          : { id: line.slice(0, tab), preview: line.slice(tab + 1) }
    }
    function _isImage(p) { return /^\[\[\s*binary data.*\]\]$/i.test(p.trim()) }
    function _isColor(p) { return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(p.trim()) }
    function _isLink(p)  { return /^(https?:\/\/|www\.)\S+$/i.test(p.trim()) }
    function shQuote(s)  { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function _imgMeta(p) {
        const m = p.match(/binary data\s+([\d.]+\s*[A-Za-z]+)\s+(\w+)\s+(\d+)x(\d+)/i)
        return m ? { size: m[1], fmt: m[2], w: parseInt(m[3]), h: parseInt(m[4]) } : null
    }

    readonly property var entries: {
        const q = root.filterText.trim().toLowerCase()
        return root.rawLines.map(_parse).map(e => {
            const p = e.preview.trim()
            const kind = _isImage(p) ? "image" : _isColor(p) ? "color" : _isLink(p) ? "link" : "text"
            return { id: e.id, preview: p, kind: kind, meta: kind === "image" ? _imgMeta(p) : null }
        }).filter(e => q.length === 0 || e.preview.toLowerCase().includes(q))
    }
    onEntriesChanged: _syncThumbs()

    function copyEntry(id) {
        copyProc.exec(["sh", "-c", "cliphist decode " + shQuote(id) + " | wl-copy"])
    }
    Process { id: copyProc }

    readonly property string _dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    property string previewId: ""
    property int    previewRev: 0
    readonly property url previewUrl: previewId.length > 0
        ? Qt.resolvedUrl("file://" + _dir + "/gimbal-clip-preview?v=" + previewRev) : ""

    function showImage(id) {
        if (id === root.previewId) return
        root.previewId = id
        imgProc.exec(["sh", "-c",
            "cliphist decode " + shQuote(id) + " > " + shQuote(_dir + "/gimbal-clip-preview")])
    }
    Process {
        id: imgProc
        onRunningChanged: if (!running) root.previewRev++
    }

    readonly property string _thumbDir: _dir + "/gimbal-clip-thumbs"
    property var _thumbSeen: ({})
    property int thumbRev: 0
    Process { id: mkdirProc }
    Process { id: thumbProc; onRunningChanged: if (!running) root.thumbRev++ }

    function _syncThumbs() {
        if (!root.active) return
        const ids = root.entries.filter(e => e.kind === "image").slice(0, 40)
                        .filter(e => !root._thumbSeen[e.id]).map(e => e.id)
        if (ids.length === 0) return
        ids.forEach(id => root._thumbSeen[id] = true)
        thumbProc.exec(["sh", "-c",
            "cd " + shQuote(_thumbDir) + " && for i in " + ids.join(" ")
            + '; do [ -s "$i" ] || cliphist decode "$i" > "$i"; done'])
    }
    function thumbUrl(id) {
        return root.thumbRev >= 0
            ? Qt.resolvedUrl("file://" + _thumbDir + "/" + id + "?r=" + root.thumbRev) : ""
    }

    property string fullId: ""
    property string fullText: ""
    function decodeText(id) {
        if (id === root.fullId) return
        root.fullId = id
        root.fullText = ""
        txtProc.exec(["sh", "-c", "cliphist decode " + shQuote(id)])
    }
    Process {
        id: txtProc
        stdout: StdioCollector {
            onStreamFinished: root.fullText = this.text
        }
    }
}
