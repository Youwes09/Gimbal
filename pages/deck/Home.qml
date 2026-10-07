import QtQuick
import Quickshell
import "root:/modules"

// Overview. A greeting, your most-used apps as one row of keys, then two lists side by side:
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

    readonly property string greeting: {
        const h = Status.now.getHours()
        return h < 5 ? "Up late" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    readonly property string summary: {
        const bits = []
        const n = Notifications.historyModel.count
        bits.push(n === 0 ? "No notifications" : n + (n === 1 ? " notification" : " notifications"))
        const d = Projects.dirtyCount
        if (d > 0) bits.push(d + (d === 1 ? " project with changes" : " projects with changes"))
        if (Status.playing) bits.push("playing " + Status.player.trackTitle)
        return bits.join("  ·  ")
    }

    function ago(ms) {
        if (!ms) return ""
        const s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }
    function strip(s) {
        return String(s || "").replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">").replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim()
    }
    function noteIcon(r) {
        const s = (/^image:\/\/qsimage/.test(r.image) ? "" : r.image) || r.appIcon || r.desktopEntry
        if (!s) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }

    readonly property real rowH: DeckUi.f(52)
    readonly property real rowGap: DeckUi.f(4)
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

    // ── header ──────────────────────────────────────────────────────────
    Column {
        id: header
        anchors.left: parent.left
        anchors.right: wallBtn.left
        anchors.rightMargin: DeckUi.f(12)
        spacing: DeckUi.f(6)
        Text {
            text: home.greeting
            color: DeckUi.text
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(26)
            font.weight: Font.Normal
            font.letterSpacing: DeckUi.f(26) * 0.004
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: home.summary
            color: DeckUi.dim
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12.5)
        }
    }
    Button {
        id: wallBtn
        anchors.right: parent.right
        anchors.top: parent.top
        glyph: Sh.icWallpaper
        label: "Wallpapers"
        selected: home.kb && home.pane === "head"
        onClicked: Sh.walls()
    }

    // ── frequent apps: one row of keys ──────────────────────────────────
    Caption {
        id: appsCap
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: DeckUi.f(28) }
        text: "Frequent"
    }
    Row {
        id: keys
        anchors { left: parent.left; right: parent.right; top: appsCap.bottom; topMargin: DeckUi.f(12) }
        spacing: DeckUi.f(10)
        readonly property real kw: (width - spacing * 5) / 6
        height: DeckUi.f(88)

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
                Behavior on color { ColorAnimation { duration: 120 } }

                // Key highlight along the inside of the top edge.
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: DeckUi.f(8) }
                    anchors.topMargin: 1
                    height: 1
                    color: DeckUi.sheen
                }
                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: DeckUi.f(14)
                    width: DeckUi.f(30); height: width
                    icon: Quickshell.iconPath(key.modelData.icon, true)
                    fallbackGlyph: Sh.icApp
                }
                Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(8) }
                    anchors.bottomMargin: DeckUi.f(12)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: key.modelData.name
                    color: key.sel ? DeckUi.text : DeckUi.dim
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(11)
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
            trailing: Projects.dirtyCount > 0 ? Projects.dirtyCount + " with changes" : ""
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
                    subtitle: modelData.branch.length ? modelData.branch + "  ·  " + modelData.short : modelData.short
                    badge: modelData.dirty > 0 ? "+" + modelData.dirty : ""
                    meta: home.ago(modelData.last)
                    selected: home.kb && home.pane === "proj" && home.idx === index
                    onClicked: home.openProject(modelData)
                }
            }
        }
        Text {
            anchors { left: parent.left; top: projCap.bottom; topMargin: DeckUi.f(18) }
            width: lists.colW
            visible: Projects.list.length === 0
            wrapMode: Text.WordWrap
            text: "Folders you open from the launcher will show up here."
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12)
        }

        // Notifications
        Caption {
            id: noteCap
            anchors { right: parent.right; top: parent.top }
            width: lists.colW
            text: "Notifications"
            trailing: Notifications.historyModel.count > home.notes
                      ? "+" + (Notifications.historyModel.count - home.notes) + " on page 2" : ""
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
                        readonly property var rec: Notifications.historyModel.get(index)
                        width: parent.width
                        height: home.rowH
                        icon: rec ? home.noteIcon(rec) : ""
                        glyph: Sh.icBell
                        title: rec ? home.strip(rec.summary) || rec.app : ""
                        subtitle: rec ? home.strip(rec.body) || rec.app : ""
                        meta: rec ? home.ago(rec.time) : ""
                        selected: home.kb && home.pane === "notes" && home.idx === index
                        onClicked: home.openNote(index)
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                visible: Notifications.historyModel.count === 0
                spacing: DeckUi.f(6)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Sh.icSparkles
                    color: DeckUi.faint
                    font.family: Sh.iconFont
                    font.pixelSize: DeckUi.f(20)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "All caught up"
                    color: DeckUi.dim
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(12)
                }
            }
        }
    }
}
