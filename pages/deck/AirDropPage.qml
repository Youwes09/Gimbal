import QtQuick
import "root:/modules"

// AirDrop through omdrop: the switch and how long it stays on, the Apple devices nearby, and your
// favorites. ⏎ on a device picks files and sends them; f or its star favorites it; r looks again;
// del twice removes a favorite.
Item {
    id: ad

    readonly property var peers: AirDrop.peers
    readonly property var favorites: AirDrop.favorites
    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: AirDrop.receiving; onTriggered: ad.now = Date.now() }

    // Looking runs once when the page opens and once per r.
    function look() { if (AirDrop.receiving) AirDrop.scan() }
    Component.onCompleted: ad.look()
    Component.onDestruction: AirDrop.stopScan()
    Connections {
        target: AirDrop
        function onReceivingChanged() { if (AirDrop.receiving) ad.look() }
    }

    function peerNamed(name) { return ad.peers.find(p => p.name === name) || null }
    function send(p) {
        if (!p || AirDrop.sending) return
        // The file chooser opens as a window, under the deck.
        Sh.closeDeck()
        AirDrop.send(p)
    }

    // Keyboard: "head" (btn 0 switch, 1 how long, 2 look again), "nearby" (cur), "favs" (fi),
    // "hist" (hi).
    property string row: "head"
    property int btn: 0
    property int cur: 0
    property int fi: 0
    property int hi: 0
    property string armed: ""          // favorite waiting for a second del
    readonly property bool kb: DeckUi.zone === "center"
    readonly property var history: AirDrop.history
    onPeersChanged: cur = Math.max(0, Math.min(cur, peers.length - 1))
    onFavoritesChanged: fi = Math.max(0, Math.min(fi, favorites.length - 1))
    onHistoryChanged: hi = Math.max(0, Math.min(hi, history.length - 1))

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "airdrop") return
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            const del = key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X
            if (U || D || L || R) ad.armed = ""
            if (key === Qt.Key_R) { ad.look(); return }
            if (ad.row === "head") {
                if (L) { if (ad.btn === 0) DeckUi.go("left"); else ad.btn-- }
                if (R) { if (ad.btn === 2) DeckUi.go("right"); else ad.btn++ }
                if (D) ad.row = ad.peers.length ? "nearby" : ad.favorites.length ? "favs" : ad.history.length ? "hist" : "head"
                if (enter) [AirDrop.toggle, AirDrop.nextWindow, ad.look][ad.btn]()
                return
            }
            if (ad.row === "nearby") {
                const p = ad.peers[ad.cur]
                if (L) DeckUi.go("left")
                if (R) { if (ad.favorites.length) ad.row = "favs"; else if (ad.history.length) ad.row = "hist"; else DeckUi.go("right") }
                if (U) { if (ad.cur === 0) ad.row = "head"; else ad.cur-- }
                if (D) ad.cur = Math.min(ad.peers.length - 1, ad.cur + 1)
                if (enter) ad.send(p)
                if (key === Qt.Key_F && p) AirDrop.toggleFavorite(p.name)
                return
            }
            if (L) { if (ad.peers.length) ad.row = "nearby"; else DeckUi.go("left"); return }
            if (R) { DeckUi.go("right"); return }
            if (ad.row === "hist") {
                if (U) { if (ad.hi > 0) ad.hi--; else ad.row = ad.favorites.length ? "favs" : "head" }
                if (D) ad.hi = Math.min(ad.history.length - 1, ad.hi + 1)
                if (enter) AirDrop.openEntry(ad.history[ad.hi])
                return
            }
            const name = ad.favorites[ad.fi]
            if (U) { if (ad.fi === 0) ad.row = "head"; else ad.fi-- }
            if (D) { if (ad.fi < ad.favorites.length - 1) ad.fi++; else if (ad.history.length) { ad.row = "hist"; ad.hi = 0 } }
            if (enter) ad.send(ad.peerNamed(name))
            if (del && name) {
                if (ad.armed !== name) ad.armed = name
                else { ad.armed = ""; AirDrop.removeFavorite(name) }
            }
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "AirDrop"
        detail: AirDrop.error ? AirDrop.error
              : AirDrop.busy || AirDrop.starting ? (AirDrop.receiving && !AirDrop.starting ? "Turning off…" : "Turning on…")
              : !AirDrop.available ? "omdrop isn't answering"
              : !AirDrop.receiving ? "Off"
              : !AirDrop.visible ? "Waiting for the radio"
              : "Visible as " + AirDrop.name
                + (AirDrop.since ? "  ·  on " + Net.duration(ad.now - AirDrop.since) : "")
                + (AirDrop.until > ad.now ? ", " + Math.ceil((AirDrop.until - ad.now) / 60000) + "m left" : "")
        detailTint: AirDrop.error ? DeckUi.danger : DeckUi.faint
        Button {
            glyph: AirDrop.receiving ? Sh.icRadio : Sh.icRadioOff
            label: AirDrop.receiving ? "On" : "Off"
            on: AirDrop.receiving
            selected: ad.kb && ad.row === "head" && ad.btn === 0
            onClicked: AirDrop.toggle()
        }
        Button {
            glyph: Sh.icTimer
            label: AirDrop.windowLabel
            selected: ad.kb && ad.row === "head" && ad.btn === 1
            onClicked: AirDrop.nextWindow()
        }
        Button {
            glyph: Sh.icRefresh
            label: AirDrop.scanning ? "Looking" : "Look again"
            on: AirDrop.scanning
            selected: ad.kb && ad.row === "head" && ad.btn === 2
            onClicked: ad.look()
        }
    }

    // A boxed section: drawn behind its content, padded out by `pad`.
    component Panel: Rectangle {
        property Item around
        readonly property real pad: DeckUi.f(14)
        x: around.x - pad; y: around.y - pad
        width: around.width + pad * 2; height: around.height + pad * 2
        radius: DeckUi.radius
        color: DeckUi.well
        border.width: 1
        border.color: DeckUi.line
    }
    component Empty: Text {
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(12)
    }

    Item {
        id: cols
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom
                  topMargin: DeckUi.f(30); leftMargin: DeckUi.f(14); rightMargin: DeckUi.f(14); bottomMargin: DeckUi.f(14) }
        readonly property real colW: (width - DeckUi.f(38)) / 2
        Panel { around: nearCol; z: -1 }
        Panel { around: favCol; z: -1 }
        Panel { around: histCol; z: -1 }

        Item {
            id: nearCol
            width: cols.colW
            height: cols.height

            Caption {
                id: nearCap
                width: parent.width
                text: "Nearby"
                trailing: AirDrop.scanning ? "Looking…" : ad.peers.length ? String(ad.peers.length) : ""
            }
            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: nearCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
                clip: true
                spacing: DeckUi.f(2)
                boundsBehavior: Flickable.StopAtBounds
                model: ad.peers
                currentIndex: ad.cur
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: ListRow {
                    id: near
                    required property var modelData
                    required property int index
                    readonly property bool target: AirDrop.sendTo === modelData.mac
                    width: list.width
                    glyph: /mac|imac/i.test(modelData.name || "") ? Sh.icLaptop : Sh.icPhone
                    title: modelData.name || "Unnamed device"
                    subtitle: target ? AirDrop.sendLine : ""
                    badge: target ? "Sending" : ""
                    badgeLive: true
                    selected: ad.kb && ad.row === "nearby" && ad.cur === index
                    onClicked: { ad.row = "nearby"; ad.cur = index; ad.send(modelData) }
                    Text {
                        visible: !!near.modelData.name
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sh.icStar
                        color: AirDrop.isFavorite(near.modelData.name) ? DeckUi.accent : starMa.containsMouse ? DeckUi.dim : DeckUi.faint
                        font.family: Sh.iconFont
                        font.pixelSize: DeckUi.f(14)
                        MouseArea {
                            id: starMa
                            anchors.fill: parent
                            anchors.margins: -DeckUi.f(6)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AirDrop.toggleFavorite(near.modelData.name)
                        }
                    }
                }
            }
            Empty {
                anchors { left: list.left; top: list.top; margins: DeckUi.f(10) }
                visible: list.count === 0
                text: !AirDrop.receiving ? "AirDrop is off" : AirDrop.scanning ? "Looking…" : "Nobody nearby"
            }
        }

        // The right column: favorites over history, half each.
        Item {
            id: favCol
            x: cols.colW + DeckUi.f(38)
            width: cols.colW
            height: (cols.height - DeckUi.f(38)) / 2

            Caption {
                id: favCap
                width: parent.width
                text: "Favorites"
            }
            ListView {
                id: favList
                anchors { left: parent.left; right: parent.right; top: favCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
                clip: true
                spacing: DeckUi.f(2)
                boundsBehavior: Flickable.StopAtBounds
                model: ad.favorites
                currentIndex: ad.fi
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: ListRow {
                    required property string modelData
                    required property int index
                    readonly property var peer: ad.peerNamed(modelData)
                    width: favList.width
                    glyph: Sh.icStar
                    title: modelData
                    subtitle: ad.armed === modelData ? "Remove again" : ""
                    badge: peer ? "Nearby" : ""
                    badgeLive: true
                    selected: ad.kb && ad.row === "favs" && ad.fi === index
                    onClicked: { ad.row = "favs"; ad.fi = index; ad.send(peer) }
                }
            }
            Empty {
                anchors { left: favList.left; top: favList.top; margins: DeckUi.f(10) }
                visible: favList.count === 0
                text: "No favorites"
            }
        }

        Item {
            id: histCol
            x: favCol.x
            y: favCol.height + DeckUi.f(38)
            width: cols.colW
            height: favCol.height

            Caption {
                id: histCap
                width: parent.width
                text: "History"
            }
            ListView {
                id: histList
                anchors { left: parent.left; right: parent.right; top: histCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
                clip: true
                spacing: DeckUi.f(2)
                boundsBehavior: Flickable.StopAtBounds
                model: ad.history
                currentIndex: ad.hi
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: ListRow {
                    required property var modelData
                    required property int index
                    readonly property bool incoming: modelData.dir === "in"
                    width: histList.width
                    glyph: incoming ? Sh.icArrowIn : Sh.icArrowOut
                    title: modelData.files.length === 1 ? modelData.files[0] : modelData.files.length + " files"
                    subtitle: (incoming ? "from " : "to ") + (modelData.who || "someone nearby")
                    meta: Status.ago(modelData.time)
                    badge: modelData.outcome === "declined" ? "Declined" : modelData.outcome === "missed" ? "Missed" : ""
                    selected: ad.kb && ad.row === "hist" && ad.hi === index
                    onClicked: { ad.row = "hist"; ad.hi = index; AirDrop.openEntry(modelData) }
                }
            }
            Empty {
                anchors { left: histList.left; top: histList.top; margins: DeckUi.f(10) }
                visible: histList.count === 0
                text: "Nothing sent or received yet"
            }
        }
    }
}
