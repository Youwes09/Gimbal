import QtQuick
import Quickshell
import "root:/modules"

// Overview: greeting, projects to pick back up, frequent apps, latest notifications.
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

    readonly property string greeting: {
        const h = Status.now.getHours()
        return h < 5 ? "Up late" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    readonly property string summary: {
        const bits = []
        const up = Calendar.upcoming
        if (up) bits.push((up.start <= Date.now() ? "Now: " : "") + up.title
                          + (up.start > Date.now() ? " at " + Qt.formatTime(new Date(up.start), "h:mm AP") : ""))
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
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m ago"
        if (s < 86400) return Math.round(s / 3600) + "h ago"
        return Math.round(s / 86400) + "d ago"
    }

    // ── keyboard: four panes laid out like the page ─────────────────────
    //   head (Wallpapers) / projects row / apps grid | latest notifications
    property string pane: "proj"
    property int idx: 0
    readonly property int notes: Math.min(3, Notifications.historyModel.count)
    readonly property bool kb: DeckUi.zone === "center"
    function _count(p) {
        return p === "head" ? 1 : p === "proj" ? Projects.list.length : p === "apps" ? home.apps.length : home.notes
    }
    function _to(p, i) {
        if (home._count(p) === 0) return false
        home.pane = p
        home.idx = Math.max(0, Math.min(i, home._count(p) - 1))
        return true
    }
    function openNote(i) {
        const r = Notifications.historyModel.get(i)
        Sh.closeDeck()
        Notifications.focusSender(r)
        Notifications.invoke(r.nid, "")
        Notifications.dismiss(r.nid)
    }

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "home") return
            if (home._count(home.pane) === 0 && !home._to("proj", 0) && !home._to("apps", 0)) home._to("head", 0)
            const p = home.pane, i = home.idx, n = home._count(p)
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                if (p === "head") Sh.walls()
                if (p === "proj") home.openProject(Projects.list[i])
                if (p === "apps") home.launch(home.apps[i])
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
                if (D) home._to("proj", 0) || home._to("apps", 0)
            } else if (p === "proj") {
                if (L) { if (i === 0) DeckUi.go("left"); else home.idx-- }
                if (R) { if (i === n - 1) DeckUi.go("right"); else home.idx++ }
                if (U) home._to("head", 0)
                if (D) home._to("apps", i) || home._to("notes", 0)
            } else if (p === "apps") {
                const c = i % 3
                if (L) { if (c === 0) DeckUi.go("left"); else home.idx-- }
                if (R) { if (c === 2 || i === n - 1) { if (!home._to("notes", Math.floor(i / 3))) DeckUi.go("right") } else home.idx++ }
                if (U) { if (i < 3) home._to("proj", c) || home._to("head", 0); else home.idx -= 3 }
                if (D) home.idx = Math.min(n - 1, i + 3)
            } else if (p === "notes") {
                if (L) home._to("apps", Math.min(home.apps.length - 1, i * 3 + 2)) || DeckUi.go("left")
                if (R) DeckUi.go("right")
                if (U) { if (i === 0) home._to("proj", 2) || home._to("head", 0); else home.idx-- }
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
        spacing: DeckUi.f(4)
        Text {
            text: home.greeting
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(24)
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: home.summary
            color: DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
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

    // ── continue ────────────────────────────────────────────────────────
    Caption {
        id: contCap
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: DeckUi.f(22) }
        text: "Continue"
        trailing: "your most opened folders"
    }
    Row {
        id: projRow
        anchors { left: parent.left; right: parent.right; top: contCap.bottom; topMargin: DeckUi.f(12) }
        spacing: DeckUi.f(12)
        height: DeckUi.f(104)
        readonly property real w: (width - spacing * 2) / 3

        Repeater {
            model: Projects.list
            Rectangle {
                id: pc
                required property var modelData
                required property int index
                readonly property bool sel: home.kb && home.pane === "proj" && home.idx === index
                width: projRow.w
                height: projRow.height
                radius: DeckUi.innerRadius
                color: pc.sel ? DeckUi.sel : pcMa.containsMouse ? DeckUi.hover : DeckUi.well
                border.width: 1
                border.color: pc.sel ? DeckUi.selRim : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(14) }
                    spacing: DeckUi.f(8)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sh.icFolderGit
                        color: Theme.accent
                        font.family: Sh.iconFont
                        font.pixelSize: DeckUi.f(14)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - DeckUi.f(22)
                        elide: Text.ElideRight
                        text: pc.modelData.name
                        color: Theme.fg
                        font.family: Sh.font
                        font.pixelSize: DeckUi.f(13.5)
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(14) }
                    anchors.topMargin: DeckUi.f(38)
                    elide: Text.ElideMiddle
                    text: pc.modelData.short
                    color: DeckUi.faint
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(10.5)
                }
                Row {
                    anchors { left: parent.left; bottom: parent.bottom; margins: DeckUi.f(14) }
                    spacing: DeckUi.f(6)
                    visible: pc.modelData.branch.length > 0
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sh.icGitBranch
                        color: DeckUi.dim
                        font.family: Sh.iconFont
                        font.pixelSize: DeckUi.f(11)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pc.modelData.branch
                        color: DeckUi.dim
                        font.family: Sh.font
                        font.pixelSize: DeckUi.f(11)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pc.modelData.dirty > 0 ? "+" + pc.modelData.dirty : "clean"
                        color: pc.modelData.dirty > 0 ? Theme.accent : DeckUi.faint
                        font.family: Sh.font
                        font.pixelSize: DeckUi.f(11)
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    anchors { right: parent.right; bottom: parent.bottom; margins: DeckUi.f(14) }
                    text: home.ago(pc.modelData.last)
                    color: DeckUi.faint
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(10.5)
                }
                MouseArea {
                    id: pcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: home.openProject(pc.modelData)
                }
            }
        }
    }
    Text {
        anchors.centerIn: projRow
        visible: Projects.list.length === 0
        text: "Open folders from the launcher and they'll show up here."
        color: DeckUi.dim
        font.family: Sh.font
        font.pixelSize: DeckUi.f(12)
    }

    // ── frequent apps | latest notifications ────────────────────────────
    Item {
        anchors { left: parent.left; right: parent.right; top: projRow.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(24)

        Item {
            id: appsBox
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: (parent.width - DeckUi.f(24)) * 0.46

            Caption { id: appsCap; anchors { left: parent.left; right: parent.right; top: parent.top } text: "Frequent" }
            Grid {
                id: appGrid
                anchors { left: parent.left; right: parent.right; top: appsCap.bottom; bottom: parent.bottom }
                anchors.topMargin: DeckUi.f(12)
                columns: 3
                spacing: DeckUi.f(10)
                readonly property real cw: (width - spacing * 2) / 3
                readonly property real ch: Math.min(DeckUi.f(86), (height - spacing) / 2)

                Repeater {
                    model: home.apps
                    Rectangle {
                        id: ap
                        required property var modelData
                        required property int index
                        readonly property bool sel: home.kb && home.pane === "apps" && home.idx === index
                        width: appGrid.cw
                        height: appGrid.ch
                        radius: DeckUi.innerRadius
                        color: ap.sel ? DeckUi.sel : apMa.containsMouse ? DeckUi.hover : DeckUi.well
                        border.width: 1
                        border.color: ap.sel ? DeckUi.selRim : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        AppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: DeckUi.f(13)
                            width: DeckUi.f(30); height: width
                            icon: Quickshell.iconPath(ap.modelData.icon, true)
                            fallbackGlyph: Sh.icApp
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(8) }
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: ap.modelData.name
                            color: ap.sel ? Theme.fg : DeckUi.dim
                            font.family: Sh.font
                            font.pixelSize: DeckUi.f(10.5)
                        }
                        MouseArea {
                            id: apMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: home.launch(ap.modelData)
                        }
                    }
                }
            }
        }

        Item {
            anchors { left: appsBox.right; leftMargin: DeckUi.f(24); right: parent.right; top: parent.top; bottom: parent.bottom }

            Caption {
                id: notCap
                anchors { left: parent.left; right: parent.right; top: parent.top }
                text: "Notifications"
                trailing: Notifications.historyModel.count > 3 ? "+" + (Notifications.historyModel.count - 3) + " more on 2" : ""
            }
            Column {
                anchors { left: parent.left; right: parent.right; top: notCap.bottom; topMargin: DeckUi.f(12) }
                spacing: DeckUi.f(8)
                Repeater {
                    model: Math.min(3, Notifications.historyModel.count)
                    NotifRow {
                        required property int index
                        width: parent.width
                        rec: Notifications.historyModel.get(index)
                        compact: true
                        selected: home.kb && home.pane === "notes" && home.idx === index
                        onClicked: home.openNote(index)
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: DeckUi.f(12)
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
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(12)
                }
            }
        }
    }
}
