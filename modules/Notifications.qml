pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    readonly property string _dir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/gimbal"
    readonly property string _path: _dir + "/notifications.json"

    property bool dnd: false
    property var history: []
    property ListModel popupModel: ListModel {}
    property ListModel historyModel: ListModel {}

    function _syncModel() {
        root.historyModel.clear()
        for (const r of root.history) root.historyModel.append(r)
    }

    readonly property var cfg: Config.notifications
    function _c(k, d) { return (root.cfg && root.cfg[k] !== undefined) ? root.cfg[k] : d }

    function timeoutFor(urgency) {
        return root._c("timeout", 6000)
    }

    // Display helpers shared by the toasts, the deck's notification rows and Home.
    // Notification text arrives as limited HTML; this flattens it to one plain line.
    function plain(s) {
        return String(s || "").replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim()
    }
    // Live notification images (image://qsimage) die with the notification; use the app icon then.
    function iconFor(r) {
        if (!r) return ""
        const s = (/^image:\/\/qsimage/.test(r.image || "") ? "" : r.image) || r.appIcon || r.desktopEntry
        if (!s) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function _rec(n) {
        return {
            nid:     String(n.id),
            app:     n.appName || "Notification",
            appIcon: n.appIcon || "",
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body:    n.body || "",
            image:   (n.image ? String(n.image) : ""),
            urgency: n.urgency === NotificationUrgency.Critical ? "critical"
                   : n.urgency === NotificationUrgency.Low ? "low" : "normal",
            time:    Date.now()
        }
    }

    function _ingest(n) {
        root._push(_rec(n))
    }

    function notifySynthetic(rec, forceShow) {
        root._push(Object.assign({
            nid: "synthetic:" + Date.now(), appIcon: "", desktopEntry: "",
            body: "", image: "", urgency: "normal", time: Date.now()
        }, rec), !!forceShow)
    }

    function _push(r, forceShow) {
        const h = root.history.slice()
        h.unshift(r)
        if (h.length > 100) h.length = 100
        root.history = h
        root.historyModel.insert(0, r)
        while (root.historyModel.count > 100) root.historyModel.remove(root.historyModel.count - 1)
        _saveTimer.restart()

        const crit = r.urgency === "critical"
        if (!root.dnd || (crit && root._c("dndBypassCritical", true)) || forceShow) {
            while (root.popupModel.count) root.popupModel.remove(0)
            root.popupModel.append(r)
        }
    }

    function dismissPopup(nid) {
        for (let i = 0; i < root.popupModel.count; i++)
            if (String(root.popupModel.get(i).nid) === String(nid)) { root.popupModel.remove(i); return }
    }

    function _live(nid) {
        const t = root.server.trackedNotifications
        const arr = t && t.values ? t.values : []
        for (const n of arr) if (String(n.id) === String(nid)) return n
        return null
    }

    function dismiss(nid) {
        dismissPopup(nid)
        const n = _live(nid)
        if (n) n.dismiss()
        root.history = root.history.filter(r => String(r.nid) !== String(nid))
        for (let i = 0; i < root.historyModel.count; i++)
            if (String(root.historyModel.get(i).nid) === String(nid)) { root.historyModel.remove(i); break }
        _saveTimer.restart()
    }

    function clearAll() {
        while (root.popupModel.count) root.popupModel.remove(0)
        const t = root.server.trackedNotifications
        const arr = t && t.values ? t.values.slice() : []
        for (const n of arr) n.dismiss()
        root.history = []
        root.historyModel.clear()
        _saveTimer.restart()
    }

    function invoke(nid, actionId) {
        const n = _live(nid)
        if (!n || !n.actions) return
        for (const a of n.actions) {
            const id = a.identifier
            if (id === actionId || (!actionId && (id === "default" || id === ""))) { a.invoke(); return }
        }
    }

    function toggleDnd() {
        root.dnd = !root.dnd
        _saveTimer.restart()
        root.notifySynthetic({
            app: "Gimbal",
            summary: root.dnd ? "Do Not Disturb enabled" : "Do Not Disturb disabled",
            body: root.dnd ? "Notifications will stay quiet until you turn this off."
                           : "You'll see new notifications again.",
            urgency: "normal"
        }, true)
    }

    function focusSender(rec) {
        if (rec) Compositor.focus([rec.desktopEntry, rec.app])
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        onNotification: (n) => { n.tracked = true; root._ingest(n) }
    }

    // Nothing is saved until the file has been read: a notification that lands while the
    // shell is still starting is merged in front of the saved history, never written over it.
    property bool _loaded: false
    property FileView _file: FileView {
        path: root._path
        onLoaded: {
            let j = {}
            try { j = JSON.parse(text() || "{}") }
            catch (e) {
                // Unreadable: set it aside before the next save replaces it.
                Quickshell.execDetached(["cp", "-f", root._path, root._path + ".bad"])
            }
            const saved = (Array.isArray(j.items) ? j.items : [])
                .map(r => Object.assign({}, r, { nid: String(r.nid) }))
            const early = root.history
            const seen = new Set(early.map(r => String(r.nid)))
            root.dnd = !!j.dnd
            root.history = early.concat(saved.filter(r => !seen.has(r.nid))).slice(0, 100)
            root._loaded = true
            root._syncModel()
            if (early.length) _saveTimer.restart()
        }
        onLoadFailed: { root._loaded = true; root._syncModel() }   // no file yet
    }

    // Written to a temp file and renamed, so a reload never reads a half-written history.
    function _save() {
        if (!root._loaded) return
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + root._q(root._dir) + " && printf '%s' "
            + root._q(JSON.stringify({ dnd: root.dnd, items: root.history }))
            + " > " + root._q(root._path + ".tmp") + " && mv " + root._q(root._path + ".tmp")
            + " " + root._q(root._path)])
    }
    property Timer _saveTimer: Timer {
        interval: 500
        onTriggered: root._save()
    }
}
