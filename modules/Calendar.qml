pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/modules"

// Read-only calendar from iCal feeds (Google Calendar's "secret address in iCal format" works).
// Feeds live in ~/.config/gimbal/calendars, one per line, optionally "Label | URL". The file is
// kept out of config.json because those addresses are secrets. Fetched when the deck opens,
// at most every 15 minutes; nothing runs in the background.
QtObject {
    id: root

    readonly property string _path: (Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config") + "/gimbal/calendars"

    property var feeds: []        // [{ label, url }]
    property var events: []       // [{ title, location, meet, start, end, allDay, cal, color }], sorted
    property bool loading: false
    property string error: ""
    property real fetched: 0
    readonly property bool configured: root.feeds.length > 0

    readonly property var _palette: [Theme.accent, Theme.second, Theme.third, Theme.contrast]

    property FileView _file: FileView {
        path: root._path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.feeds = this.text().split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#")).map(l => {
                const i = l.indexOf("|")
                return i < 0 ? { label: "", url: l } : { label: l.slice(0, i).trim(), url: l.slice(i + 1).trim() }
            })
            root.fetched = 0
            if (!root.configured) root.events = []
            if (Sh.deckShown) root.refresh()
        }
        onLoadFailed: { root.feeds = []; root.events = [] }
    }

    property Connections _deck: Connections {
        target: Sh
        function onDeckShownChanged() {
            if (Sh.deckShown && Date.now() - root.fetched > 15 * 60 * 1000) root.refresh()
        }
    }

    // ── queries ─────────────────────────────────────────────────────────
    function dayStart(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() }
    function on(d) {
        const a = root.dayStart(d), b = a + 86400000
        return root.events.filter(e => e.start < b && (e.end > a || e.start >= a))
    }
    // The next timed event that hasn't ended, within a day.
    readonly property var upcoming: {
        const _ = Status.now
        const now = Date.now()
        return root.events.find(e => !e.allDay && e.end > now && e.start < now + 86400000) || null
    }

    function refresh() {
        if (!root.configured || root.loading) return
        root.loading = true
        root.error = ""
        const out = [], failed = []
        let left = root.feeds.length
        root.feeds.forEach((f, i) => {
            const x = new XMLHttpRequest()
            x.onreadystatechange = () => {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status === 200) {
                    try { root._parse(x.responseText, f.label, root._palette[i % root._palette.length], out) }
                    catch (e) { failed.push(f.label || "feed " + (i + 1)) }
                } else failed.push(f.label || "feed " + (i + 1))
                if (--left === 0) {
                    out.sort((a, b) => a.start - b.start || (b.allDay - a.allDay))
                    root.events = out
                    root.error = failed.length ? "Couldn't load " + failed.join(", ") : ""
                    root.fetched = Date.now()
                    root.loading = false
                }
            }
            x.open("GET", f.url)
            x.send()
        })
    }

    // ── iCal ────────────────────────────────────────────────────────────
    function _unescape(s) { return s.replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim() }

    // TZID times are taken as local wall time; UTC ("Z") times are converted.
    function _date(v) {
        const y = +v.slice(0, 4), mo = +v.slice(4, 6) - 1, d = +v.slice(6, 8)
        if (v.length <= 8) return new Date(y, mo, d).getTime()
        const h = +v.slice(9, 11), mi = +v.slice(11, 13), s = +v.slice(13, 15)
        return v.endsWith("Z") ? Date.UTC(y, mo, d, h, mi, s) : new Date(y, mo, d, h, mi, s).getTime()
    }
    function _duration(v) {
        const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v)
        if (!m) return 0
        return ((+m[2] || 0) * 604800 + (+m[3] || 0) * 86400 + (+m[4] || 0) * 3600 + (+m[5] || 0) * 60 + (+m[6] || 0)) * 1000
    }

    function _parse(text, label, color, out) {
        const lines = text.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
        const masters = [], overrides = []
        let ev = null
        for (const l of lines) {
            if (l === "BEGIN:VEVENT") { ev = { exdates: [] }; continue }
            if (l === "END:VEVENT") { if (ev && ev.start !== undefined) (ev.recurId !== undefined ? overrides : masters).push(ev); ev = null; continue }
            if (!ev) continue
            const c = l.indexOf(":")
            if (c < 0) continue
            const head = l.slice(0, c).split(";"), val = l.slice(c + 1), name = head[0]
            if (name === "DTSTART") { ev.start = root._date(val); ev.allDay = val.length <= 8 }
            else if (name === "DTEND") ev.end = root._date(val)
            else if (name === "DURATION") ev.dur = root._duration(val)
            else if (name === "SUMMARY") ev.title = root._unescape(val)
            else if (name === "LOCATION") ev.location = root._unescape(val)
            else if (name === "RRULE") {
                ev.rrule = {}
                for (const p of val.split(";")) { const kv = p.split("="); ev.rrule[kv[0]] = kv[1] }
            }
            else if (name === "EXDATE") for (const d of val.split(",")) ev.exdates.push(root._date(d))
            else if (name === "RECURRENCE-ID") ev.recurId = root._date(val)
            else if (name === "UID") ev.uid = val
            else if (name === "STATUS") ev.status = val
            else if (name === "DESCRIPTION") {
                const m = /https:\/\/meet\.google\.com\/[a-z0-9-]+/i.exec(val)
                if (m) ev.meet = m[0]
            }
        }

        const now = new Date()
        const from = new Date(now.getFullYear(), now.getMonth() - 4, 1).getTime()
        const to = new Date(now.getFullYear(), now.getMonth() + 13, 1).getTime()
        const moved = new Set(overrides.map(o => o.uid + "|" + o.recurId))

        const emit = (ev, t) => {
            const len = ev.end !== undefined ? ev.end - ev.start : ev.dur || (ev.allDay ? 86400000 : 0)
            if (t >= to || t + len < from) return
            out.push({ title: ev.title || "(No title)", location: ev.location || "", meet: ev.meet || "",
                       start: t, end: t + len, allDay: !!ev.allDay, cal: label, color: color })
        }

        for (const o of overrides) if (o.status !== "CANCELLED") emit(o, o.start)
        for (const ev of masters) {
            if (ev.status === "CANCELLED") continue
            if (!ev.rrule) { emit(ev, ev.start); continue }
            const skip = new Set(ev.exdates)
            root._expand(ev, to, t => { if (!skip.has(t) && !moved.has(ev.uid + "|" + t)) emit(ev, t) })
        }
    }

    // Walks a recurrence from its first instance. Covers DAILY / WEEKLY (BYDAY) /
    // MONTHLY (day of month, or BYDAY like 2TU / -1FR) / YEARLY with INTERVAL, COUNT, UNTIL.
    function _expand(ev, to, each) {
        const r = ev.rrule, step = +r.INTERVAL || 1
        const until = r.UNTIL ? root._date(r.UNTIL) : Infinity
        let count = r.COUNT ? +r.COUNT : Infinity
        const base = new Date(ev.start)
        const days = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        const take = t => {
            if (t > until || count <= 0 || t >= to) return false
            if (t >= ev.start) { count--; each(t) }
            return true
        }
        const at = (y, m, d) => new Date(y, m, d, base.getHours(), base.getMinutes(), base.getSeconds()).getTime()

        for (let k = 0; k < 20000; k++) {
            if (r.FREQ === "DAILY") {
                if (!take(at(base.getFullYear(), base.getMonth(), base.getDate() + k * step))) return
            } else if (r.FREQ === "WEEKLY") {
                const by = r.BYDAY ? r.BYDAY.split(",").map(s => days.indexOf(s.slice(-2))).sort() : [base.getDay()]
                const sun = base.getDate() - base.getDay() + k * 7 * step
                for (const wd of by) if (!take(at(base.getFullYear(), base.getMonth(), sun + wd))) return
            } else if (r.FREQ === "MONTHLY") {
                const y = base.getFullYear(), m = base.getMonth() + k * step
                const first = new Date(y, m, 1), dim = new Date(y, m + 1, 0).getDate()
                let d = base.getDate()
                const nth = r.BYDAY && /^([+-]?\d)(\w\w)$/.exec(r.BYDAY)
                if (nth) {
                    const wd = days.indexOf(nth[2]), n = +nth[1]
                    const firstWd = 1 + (wd - first.getDay() + 7) % 7
                    d = n > 0 ? firstWd + (n - 1) * 7 : firstWd + Math.floor((dim - firstWd) / 7) * 7 + (n + 1) * 7
                }
                if (d >= 1 && d <= dim && !take(at(y, m, d))) return
                if (first.getTime() >= to) return
            } else if (r.FREQ === "YEARLY") {
                if (!take(at(base.getFullYear() + k * step, base.getMonth(), base.getDate()))) return
            } else return
        }
    }
}
