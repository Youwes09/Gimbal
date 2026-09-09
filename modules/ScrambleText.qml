import QtQuick
import "root:/modules"

Text {
    id: root

    property string content: ""
    property int delay: 0
    property int span: 720
    property int hold: 45

    property bool gateOnReveal: true
    property bool show: true

    readonly property string alphabet:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#%&@*?/\\<>=+$"
    readonly property int _seed: Math.floor(Math.random() * 0x10000)

    property string _phase: "idle"
    property bool   _playedIn: false
    property real   _elapsed: 0

    function _centreReached() {
        const c = mapToItem(null, width / 2, height / 2)
        return Sh.reached(c.x, c.y)
    }
    function _startIn() {
        root._phase = "in"
        clock.t0 = Date.now()
        root._elapsed = -root.delay
        clock.restart()
    }
    function _startOut() {
        if (root._phase === "out") return
        root._phase = "out"
        clock.t0 = Date.now()
        root._elapsed = 0
        clock.restart()
    }

    Connections {
        target: Sh
        function onRevealChanged() {
            if (root.gateOnReveal && root._phase === "idle" && !root._playedIn
                && root.show && root._centreReached())
                root._startIn()
        }
        function onShownChanged() {
            if (Sh.shown) {
                root._playedIn = false
                root._phase = "idle"
                clock.stop()
            } else if (root._playedIn || root._phase === "in") {
                root._startOut()
            }
        }
    }
    onShowChanged: {
        if (root.gateOnReveal) return
        if (root.show && root._phase !== "in" && !root._playedIn) root._startIn()
        else if (!root.show && root._playedIn) { root._playedIn = false; root._startOut() }
    }
    Component.onCompleted: {
        if (!root.gateOnReveal && root.show) root._startIn()
        else if (root.gateOnReveal && Sh.reveal >= 1 && root.show && _centreReached()) _startIn()
    }

    Timer {
        id: clock
        interval: root.hold
        repeat: true
        property real t0: 0
        onTriggered: {
            root._elapsed = Date.now() - t0 - root.delay
            if (root._elapsed >= root.span) {
                root._elapsed = root.span
                running = false
                if (root._phase === "in") { root._phase = "idle"; root._playedIn = true }
            }
        }
    }

    function _hash(seed, i, frame) {
        let h = Math.imul(seed ^ 0x9e3779b9, 0x85ebca6b)
        h = Math.imul(h ^ i, 0xc2b2ae35)
        h = Math.imul(h ^ frame, 0x27d4eb2f)
        return (h ^ (h >>> 15)) & 0x3fffffff
    }
    function _index(h, n, banA, banB) {
        const lo = Math.min(banA, banB)
        const hi = Math.max(banA, banB)
        const first = lo >= 0 ? lo : hi
        const second = (lo >= 0 && hi > lo) ? hi : -1
        let idx = h % (n - (first >= 0 ? 1 : 0) - (second >= 0 ? 1 : 0))
        if (first >= 0 && idx >= first) idx++
        if (second >= 0 && idx >= second) idx++
        return idx
    }
    function _glyph(seed, i, frame, avoid) {
        let idx = -1
        for (let f = 0; f <= frame; f++)
            idx = _index(_hash(seed, i, f), alphabet.length, idx, f === frame ? avoid : -1)
        return alphabet.charAt(idx)
    }

    text: {
        const s = root.content
        const n = s.length
        if (root._phase === "idle" || n === 0) return s
        const e = root._elapsed
        const dissolve = root._phase === "out"
        if (!dissolve && e >= root.span) return s
        const frame = Math.floor(Math.max(0, e) / root.hold)
        let out = ""
        for (let i = 0; i < n; i++) {
            const ch = s.charAt(i)
            if (ch === " " || ch === "\n" || ch === "\t") { out += ch; continue }
            const lockAt = (i + 1) / n * root.span
            const locked = e >= lockAt
            if (!dissolve) {
                if (locked) { out += ch; continue }
                const lastFrame = (frame + 1) * root.hold >= lockAt
                out += _glyph(root._seed, i, frame, lastFrame ? alphabet.indexOf(ch) : -1)
            } else {
                if (!locked) { out += ch; continue }
                out += _glyph(root._seed, i, frame, -1)
            }
        }
        return out
    }
}
