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
        if (urgency === "critical") return root._c("timeoutCritical", 0)
        if (urgency === "low")      return root._c("timeoutLow", 4000)
        return root._c("timeout", 6000)
    }

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function _rec(n) {
        return {
            nid:     n.id,
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
        const r = _rec(n)
        const h = root.history.slice()
        h.unshift(r)
        if (h.length > 100) h.length = 100
        root.history = h
        root.historyModel.insert(0, r)
        while (root.historyModel.count > 100) root.historyModel.remove(root.historyModel.count - 1)
        _saveTimer.restart()

        const crit = r.urgency === "critical"
        if (!root.dnd || (crit && root._c("dndBypassCritical", true))) {
            while (root.popupModel.count) root.popupModel.remove(0)
            root.popupModel.append(r)
        }
    }

    function dismissPopup(nid) {
        for (let i = 0; i < root.popupModel.count; i++)
            if (root.popupModel.get(i).nid === nid) { root.popupModel.remove(i); return }
    }

    function _live(nid) {
        const t = root.server.trackedNotifications
        const arr = t && t.values ? t.values : []
        for (const n of arr) if (n.id === nid) return n
        return null
    }

    function dismiss(nid) {
        dismissPopup(nid)
        const n = _live(nid)
        if (n) n.dismiss()
        root.history = root.history.filter(r => r.nid !== nid)
        for (let i = 0; i < root.historyModel.count; i++)
            if (root.historyModel.get(i).nid === nid) { root.historyModel.remove(i); break }
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

    function toggleDnd() { root.dnd = !root.dnd; _saveTimer.restart() }

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

    property FileView _file: FileView {
        path: root._path
        onLoaded: {
            try {
                const j = JSON.parse(text() || "{}")
                root.dnd = !!j.dnd
                root.history = Array.isArray(j.items) ? j.items : []
            } catch (e) { root.dnd = false; root.history = [] }
            root._syncModel()
        }
        onLoadFailed: { root.dnd = false; root.history = []; root._syncModel() }
    }

    property Timer _saveTimer: Timer {
        interval: 500
        onTriggered: Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + root._q(root._dir) + " && printf '%s' "
            + root._q(JSON.stringify({ dnd: root.dnd, items: root.history }))
            + " > " + root._q(root._path)])
    }
}
