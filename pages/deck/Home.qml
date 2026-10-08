import QtQuick
import Quickshell
import "root:/modules"

// Overview. Your most-used apps as one row of keys, then two lists side by side:
// folders to pick back up and the latest notifications. Both lists share one row style and
// grow to fill the page.
Item {
    id: home

    // ── data ────────────────────────────────────────────────────────────
    readonly property var apps: {
        const _ = Frecency.rev
        return Frecency.top("app:", 6).map(k => DesktopEntries.byId(k.slice(4))).filter(a => a)
    }
    function launch(a) {
        Frecency.bump("app:" + a.id)
        Sh.closeDeck()
        const go = () => {
            if (!a.runInTerminal && a.command && a.command.length) Compositor.spawn(a.command)
            else a.execute()
            Launches.begin(a.name, Quickshell.iconPath(a.icon, true), [a.startupClass, a.id, a.name])
        }
        if (Config.raiseRunning) Compositor.raiseOrRun([a.startupClass, a.id, a.name], go)
        else go()
    }
    function openProject(p) { Sh.closeDeck(); Projects.open(p.path) }
    function openNote(i) {
        const r = Notifications.historyModel.get(i)
        Sh.closeDeck()
        Notifications.focusSender(r)
        Notifications.invoke(r.nid, "")
        Notifications.dismiss(r.nid)
    }

    readonly property real rowH: DeckUi.f(40)
    readonly property real rowGap: DeckUi.f(2)
    // As many notifications as the right list has room for.
    readonly property int notes: Math.min(Notifications.historyModel.count,
        Math.max(1, Math.floor((notesList.height + home.rowGap) / (home.rowH + home.rowGap))))

    // ── keyboard: four panes laid out like the page ─────────────────────
    //   head (Wallpapers) / app keys / projects | notifications
    property string pane: "apps"
    property int idx: 0
    readonly property bool kb: DeckUi.zone === "center"
    function _count(p) {
        return p === "head" ? 1 : p === "apps" ? home.apps.length : p === "proj" ? Projects.list.length : home.notes
    }
    function _to(p, i) {
        if (home._count(p) === 0) return false
        home.pane = p
        home.idx = Math.max(0, Math.min(i, home._count(p) - 1))
        return true
    }

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "home") return
            if (home._count(home.pane) === 0 && !home._to("apps", 0) && !home._to("proj", 0)) home._to("head", 0)
            const p = home.pane, i = home.idx, n = home._count(p)
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                if (p === "head") Sh.walls()
                if (p === "apps") home.launch(home.apps[i])
                if (p === "proj") home.openProject(Projects.list[i])
                if (p === "notes") home.openNote(i)
                return
            }
            if (p === "notes" && (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X)) {
                Notifications.dismiss(Notifications.historyModel.get(i).nid)
                // The next one slides up into this slot; keep the selection here, or step back
                // to the projects once the list is empty.
                Qt.callLater(() => { if (!home._to("notes", i)) home._to("proj", 0) || home._to("apps", 0) })
                return
            }
            if (p === "head") {
                if (L) DeckUi.go("left")
                if (R) DeckUi.go("right")
                if (D) home._to("apps", 0) || home._to("proj", 0)
            } else if (p === "apps") {
                if (L) { if (i === 0) DeckUi.go("left"); else home.idx-- }
                if (R) { if (i === n - 1) DeckUi.go("right"); else home.idx++ }
                if (U) home._to("head", 0)
                // Down lands in whichever list sits under this key.
                if (D) (i < 3 ? home._to("proj", 0) || home._to("notes", 0) : home._to("notes", 0) || home._to("proj", 0))
            } else if (p === "proj") {
                if (L) DeckUi.go("left")
                if (R) { if (!home._to("notes", i)) DeckUi.go("right") }
                if (U) { if (i === 0) home._to("apps", 1) || home._to("head", 0); else home.idx-- }
                if (D) home.idx = Math.min(n - 1, i + 1)
            } else if (p === "notes") {
                if (L) { if (!home._to("proj", i)) DeckUi.go("left") }
                if (R) DeckUi.go("right")
                if (U) { if (i === 0) home._to("apps", 4) || home._to("head", 0); else home.idx-- }
                if (D) home.idx = Math.min(n - 1, i + 1)
            }
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "Home"
        Button {
            glyph: Sh.icWallpaper
            label: "Wallpapers"
            selected: home.kb && home.pane === "head"
            onClicked: Sh.walls()
        }
    }

    // ── frequent apps: one row of keys ──────────────────────────────────
    Caption {
        id: appsCap
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: DeckUi.f(16) }
        text: "Frequent"
    }
    Row {
        id: keys
        anchors { left: parent.left; right: parent.right; top: appsCap.bottom; topMargin: DeckUi.f(10) }
        spacing: DeckUi.f(10)
        readonly property real kw: (width - spacing * 5) / 6
        height: DeckUi.f(68)

        Repeater {
            model: home.apps
            Rectangle {
                id: key
                required property var modelData
                required property int index
                readonly property bool sel: home.kb && home.pane === "apps" && home.idx === index
                width: keys.kw
                height: keys.height
                radius: DeckUi.f(12)
                color: key.sel ? DeckUi.sel : keyMa.containsMouse ? DeckUi.hover : DeckUi.well
                border.width: 1
                border.color: key.sel ? DeckUi.selRim : DeckUi.line
                Behavior on color { CAnim {} }

                // Key highlight along the inside of the top edge.
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: DeckUi.f(8) }
                    anchors.topMargin: 1
                    height: 1
                    color: DeckUi.sheen
                }
                AppIcon {
                    anchors.centerIn: parent
                    width: DeckUi.f(32); height: width
                    icon: Quickshell.iconPath(key.modelData.icon, true)
                    fallbackGlyph: Sh.icApp
                }
                MouseArea {
                    id: keyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: home.launch(key.modelData)
                }
            }
        }
    }

    // ── continue | notifications ────────────────────────────────────────
    Item {
        id: lists
        anchors { left: parent.left; right: parent.right; top: keys.bottom; bottom: parent.bottom; topMargin: DeckUi.f(28) }
        readonly property real colW: (width - DeckUi.f(28)) / 2

        // Continue
        Caption {
            id: projCap
            anchors { left: parent.left; top: parent.top }
            width: lists.colW
            text: "Continue"
            trailing: Projects.dirtyCount > 0 ? Projects.dirtyCount + " changed" : ""
        }
        Column {
            anchors { left: parent.left; top: projCap.bottom; topMargin: DeckUi.f(10) }
            width: lists.colW
            spacing: home.rowGap
            Repeater {
                model: Projects.list
                ListRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: home.rowH
                    glyph: Sh.icFolderGit
                    title: modelData.name
                    subtitle: modelData.branch.length ? modelData.branch : modelData.short
                    badge: modelData.dirty > 0 ? "+" + modelData.dirty : ""
                    meta: Status.ago(modelData.last)
                    selected: home.kb && home.pane === "proj" && home.idx === index
                    onClicked: home.openProject(modelData)
                }
            }
        }

        // Notifications
        Caption {
            id: noteCap
            anchors { right: parent.right; top: parent.top }
            width: lists.colW
            text: "Notifications"
            trailing: Notifications.historyModel.count > 0 ? String(Notifications.historyModel.count) : ""
        }
        Item {
            id: notesList
            anchors { right: parent.right; top: noteCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(10) }
            width: lists.colW
            Column {
                width: parent.width
                spacing: home.rowGap
                Repeater {
                    model: home.notes
                    ListRow {
                        required property int index
                        // get() isn't reactive; reading count re-fetches on every insert/removal.
                        readonly property var rec: { Notifications.historyModel.count; return Notifications.historyModel.get(index) }
                        width: parent.width
                        height: home.rowH
                        icon: rec ? Notifications.iconFor(rec) : ""
                        glyph: Sh.icBell
                        title: rec ? Notifications.plain(rec.summary) || rec.app : ""
                        subtitle: rec ? Notifications.plain(rec.body) || rec.app : ""
                        meta: rec ? Status.ago(rec.time) : ""
                        selected: home.kb && home.pane === "notes" && home.idx === index
                        onClicked: home.openNote(index)
                    }
                }
            }
        }
    }
}
