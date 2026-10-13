import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/modules"

// GitHub accounts: profile, a year of contributions, recent repos and activity.
// ←→ account · ↓ into the lists · enter open · r refresh.
Item {
    id: gh

    property int acct: 0
    readonly property var account: GitHub.accounts[Math.min(gh.acct, GitHub.accounts.length - 1)] || null
    readonly property var d: gh.account ? GitHub.data[gh.account.user] || null : null
    readonly property var days: gh.d ? gh.d.days : []
    readonly property var repos: gh.d ? gh.d.repos.slice(0, lists.fit) : []
    readonly property var events: gh.d ? gh.d.events.slice(0, lists.fit) : []
    readonly property bool tokenless: !!gh.d && !gh.d.authed

    Component.onCompleted: GitHub.refresh(false)

    function open(url) { if (url) { Sh.closeDeck(); Quickshell.execDetached(["xdg-open", url]) } }

    // Keyboard: the header buttons (row -1), then the repo and activity columns.
    property int row: -1
    property int col: 0
    property int btn: 0
    readonly property var bar: GitHub.accounts.map((a, i) => () => gh.acct = i)
        .concat([() => GitHub.refresh(true), () => gh.open(gh.d ? gh.d.profile.url : "")])
    readonly property var lists: [gh.repos, gh.events]
    readonly property bool kb: DeckUi.zone === "center"
    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "github") return
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            if (key === Qt.Key_R) { GitHub.refresh(true); return }
            if (gh.row < 0) {
                if (key === Qt.Key_Left)  { if (gh.btn === 0) DeckUi.go("left"); else gh.btn-- }
                if (key === Qt.Key_Right) { if (gh.btn === gh.bar.length - 1) DeckUi.go("right"); else gh.btn++ }
                if (key === Qt.Key_Down && gh.lists[gh.col].length > 0) gh.row = 0
                if (enter) gh.bar[gh.btn]()
                return
            }
            const n = gh.lists[gh.col].length
            if (key === Qt.Key_Up)    gh.row--
            if (key === Qt.Key_Down)  gh.row = Math.min(n - 1, gh.row + 1)
            if (key === Qt.Key_Left)  { if (gh.col === 0) DeckUi.go("left"); else if (gh.lists[0].length) { gh.col = 0; gh.row = Math.min(gh.row, gh.lists[0].length - 1) } }
            if (key === Qt.Key_Right) { if (gh.col === 1 || !gh.lists[1].length) DeckUi.go("right"); else { gh.col = 1; gh.row = Math.min(gh.row, gh.lists[1].length - 1) } }
            if (enter) { const it = gh.lists[gh.col][gh.row]; if (it) gh.open(it.url) }
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "GitHub"
        detail: !gh.account ? "" : GitHub.loading === gh.account.user ? "Refreshing…"
              : gh.d ? gh.d.total.toLocaleString(Qt.locale(), "f", 0) + " contribution" + (gh.d.total === 1 ? "" : "s") + " in the last year" : ""
        Repeater {
            model: GitHub.accounts.length > 1 ? GitHub.accounts : []
            Button {
                required property var modelData
                required property int index
                label: modelData.user
                on: gh.acct === index
                selected: gh.kb && gh.row < 0 && gh.btn === index
                onClicked: gh.acct = index
            }
        }
        Button {
            glyph: Sh.icRefresh
            selected: gh.kb && gh.row < 0 && gh.btn === gh.bar.length - 2
            onClicked: GitHub.refresh(true)
        }
        Button {
            glyph: Sh.icExternal
            selected: gh.kb && gh.row < 0 && gh.btn === gh.bar.length - 1
            onClicked: gh.open(gh.d ? gh.d.profile.url : "")
        }
    }

    Item {
        id: body
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(18)
        visible: gh.d !== null

        // Who, and the numbers worth a glance.
        Item {
            id: profile
            width: parent.width
            height: DeckUi.f(44)

            ClippingRectangle {
                id: avatar
                width: profile.height; height: width
                radius: width / 2
                color: DeckUi.graphite
                Image {
                    anchors.fill: parent
                    source: gh.d && gh.d.profile.avatar ? gh.d.profile.avatar + "&s=" + Math.round(avatar.width * 2) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors { left: avatar.right; leftMargin: DeckUi.f(14); verticalCenter: parent.verticalCenter }
                spacing: DeckUi.f(2)
                Text {
                    text: gh.d ? gh.d.profile.name || gh.d.profile.login : ""
                    color: DeckUi.text
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(15)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: gh.d ? "@" + gh.d.profile.login + (gh.d.languages.length ? "  ·  " + gh.d.languages.join(", ") : "") : ""
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(11.5)
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: DeckUi.f(26)
                Repeater {
                    model: gh.d ? [
                        { v: GitHub.streak(gh.days), l: "day streak", hot: GitHub.streak(gh.days) > 0 },
                        { v: gh.d.stars, l: "stars" },
                        { v: gh.d.profile.repos, l: "repos" },
                        { v: gh.d.profile.followers, l: "followers" }
                    ] : []
                    Column {
                        required property var modelData
                        spacing: DeckUi.f(1)
                        Text {
                            anchors.right: parent.right
                            text: modelData.v
                            color: modelData.hot ? DeckUi.accent : DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(16)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            text: modelData.l
                            color: DeckUi.faint
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(10.5)
                        }
                    }
                }
            }
        }

        // A year of contributions, a column per week, Sunday on top.
        Item {
            id: graph
            anchors { left: parent.left; right: parent.right; top: profile.bottom; topMargin: DeckUi.f(20) }
            height: months.height + DeckUi.f(4) + 7 * graph.cell + 6 * graph.gap

            readonly property int off: gh.days.length ? new Date(gh.days[0].date + "T00:00:00Z").getUTCDay() : 0
            readonly property int weeks: Math.max(1, Math.ceil((gh.days.length + graph.off) / 7))
            readonly property real gap: DeckUi.f(3)
            readonly property real cell: Math.floor(Math.min(DeckUi.f(12), (width - (weeks - 1) * gap) / weeks))
            readonly property real pitch: graph.cell + graph.gap
            readonly property real x0: (width - (graph.weeks * graph.pitch - graph.gap)) / 2
            property int hover: -1

            readonly property var _names: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            Item {
                id: months
                width: parent.width
                height: DeckUi.f(14)
                Repeater {
                    // A label where each month's first full week starts.
                    model: gh.days.map((x, i) => ({ x: x, i: i })).filter(o => o.x.date.slice(8) <= "07" && (o.i + graph.off) % 7 === 0)
                    Text {
                        required property var modelData
                        x: graph.x0 + Math.floor((modelData.i + graph.off) / 7) * graph.pitch
                        text: graph._names[parseInt(modelData.x.date.slice(5, 7)) - 1]
                        color: DeckUi.faint
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(10)
                    }
                }
            }
            Repeater {
                model: gh.days
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property int slot: index + graph.off
                    x: graph.x0 + Math.floor(slot / 7) * graph.pitch
                    y: months.height + DeckUi.f(4) + (slot % 7) * graph.pitch
                    width: graph.cell; height: width
                    radius: Math.max(2, width / 4)
                    color: modelData.level === 0 ? Qt.rgba(1, 1, 1, 0.05) : Qt.alpha(DeckUi.accent, [0.3, 0.5, 0.75, 1][modelData.level - 1])
                    border.width: graph.hover === index ? 1 : 0
                    border.color: DeckUi.text
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: (m) => {
                    const c = Math.floor((m.x - graph.x0) / graph.pitch), r = Math.floor((m.y - months.height - DeckUi.f(4)) / graph.pitch)
                    const i = c * 7 + r - graph.off
                    graph.hover = c >= 0 && r >= 0 && r < 7 && i >= 0 && i < gh.days.length ? i : -1
                }
                onExited: graph.hover = -1
            }
        }

        // The hovered day, or the legend.
        Item {
            id: legend
            anchors { left: graph.left; right: graph.right; top: graph.bottom; topMargin: DeckUi.f(8) }
            anchors.leftMargin: graph.x0
            anchors.rightMargin: graph.x0
            height: DeckUi.f(16)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const x = gh.days[graph.hover]
                    if (!x) return GitHub.streak(gh.days) > 0 ? "On a " + GitHub.streak(gh.days) + "-day streak" : ""
                    const d = new Date(x.date + "T12:00:00")
                    return (x.count || "No") + " contribution" + (x.count === 1 ? "" : "s") + " on " + d.toLocaleDateString(Qt.locale(), "ddd, MMM d")
                }
                color: graph.hover >= 0 ? DeckUi.text : DeckUi.dim
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(11)
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: DeckUi.f(3)
                Text { text: "Less"; color: DeckUi.faint; font.family: DeckUi.sans; font.pixelSize: DeckUi.f(10); rightPadding: DeckUi.f(4) }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: DeckUi.f(9); height: width; radius: DeckUi.f(2)
                        color: index === 0 ? Qt.rgba(1, 1, 1, 0.05) : Qt.alpha(DeckUi.accent, [0.3, 0.5, 0.75, 1][index - 1])
                    }
                }
                Text { text: "More"; color: DeckUi.faint; font.family: DeckUi.sans; font.pixelSize: DeckUi.f(10); leftPadding: DeckUi.f(4) }
            }
        }

        Row {
            id: lists
            anchors { left: parent.left; right: parent.right; top: legend.bottom; bottom: parent.bottom; topMargin: DeckUi.f(20) }
            spacing: DeckUi.f(20)
            readonly property real colW: (width - spacing) / 2
            readonly property int fit: Math.max(0, Math.floor((height - DeckUi.f(24)) / DeckUi.f(42)))

            Column {
                width: lists.colW
                spacing: DeckUi.f(2)
                Caption { width: parent.width; text: "Repositories"; height: DeckUi.f(24) }
                Empty { shown: gh.repos.length === 0; text: gh.tokenless ? "No public repositories. A token shows private ones." : "No repositories" }
                Repeater {
                    model: gh.repos
                    ListRow {
                        required property var modelData
                        required property int index
                        width: parent.width
                        glyph: modelData.fork ? Sh.icGitFork : modelData.private ? Sh.icLock : Sh.icFolderGit
                        title: modelData.name
                        subtitle: modelData.desc
                        badge: modelData.lang
                        meta: Status.ago(modelData.pushed)
                        selected: gh.kb && gh.row === index && gh.col === 0
                        onClicked: gh.open(modelData.url)
                    }
                }
            }
            Column {
                width: lists.colW
                spacing: DeckUi.f(2)
                Caption { width: parent.width; text: "Activity"; height: DeckUi.f(24) }
                Empty { shown: gh.events.length === 0; text: gh.tokenless ? "No public activity" : "No recent activity" }
                Repeater {
                    model: gh.events
                    ListRow {
                        required property var modelData
                        required property int index
                        width: parent.width
                        glyph: ({ push: Sh.icGitCommit, pr: Sh.icGitPull, issue: Sh.icRecord, comment: Sh.icMessage,
                                  create: Sh.icFolderGit, release: Sh.icTag, star: Sh.icStar, fork: Sh.icGitFork })[modelData.kind] || Sh.icGitBranch
                        title: modelData.text
                        subtitle: modelData.sub
                        meta: Status.ago(modelData.at)
                        selected: gh.kb && gh.row === index && gh.col === 1
                        onClicked: gh.open(modelData.url)
                    }
                }
            }
        }
    }

    component Empty: Text {
        property bool shown: false
        visible: shown
        width: parent.width
        leftPadding: DeckUi.f(10)
        topPadding: DeckUi.f(8)
        wrapMode: Text.WordWrap
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(11.5)
    }

    Text {
        anchors.centerIn: parent
        visible: gh.d === null
        horizontalAlignment: Text.AlignHCenter
        text: GitHub.accounts.length === 0
            ? "Add accounts to ~/.config/gimbal/config.json\n\"github\": [\"you\", \"your-work-account\"]"
            : GitHub.loading ? "Loading " + GitHub.loading + "…" : "Couldn't reach GitHub"
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(12)
        lineHeight: 1.4
    }
}
