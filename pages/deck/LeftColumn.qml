import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import "root:/modules"

// At a glance: clock, now playing, live system tiles.
Column {
    id: col
    spacing: DeckUi.f(12)

    readonly property real innerW: col.width
    // The clock card flips the space below it into a calendar (click, or Enter on the clock).
    Connections { target: Sh; function onDeckShownChanged() { DeckUi.calendarOpen = false } }
    Connections {
        target: DeckUi
        function onCalendarOpenChanged() { if (!DeckUi.calendarOpen && DeckUi.zone === "calendar") DeckUi.zone = "clock" }
        function onNav(key) {
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            if (DeckUi.zone === "clock") {
                if (enter) DeckUi.calendarOpen = !DeckUi.calendarOpen
                if (key === Qt.Key_Right) DeckUi.go("right")
                if (key === Qt.Key_Down) DeckUi.go("down")
            } else if (DeckUi.zone === "calendar") {
                if (key === Qt.Key_Left) calendar.offset--
                if (key === Qt.Key_Right) calendar.offset++
                if (enter) calendar.offset = 0
                if (key === Qt.Key_Up) DeckUi.go("up")
            }
        }
    }

    Card {
        width: col.innerW
        height: DeckUi.f(150)
        focused: DeckUi.zone === "clock"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: DeckUi.calendarOpen = !DeckUi.calendarOpen
        }

        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: DeckUi.f(18)
            spacing: DeckUi.f(2)

            Row {
                spacing: DeckUi.f(8)
                Text {
                    id: clockText
                    text: Status.time
                    color: DeckUi.text
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(50)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: clockText.baseline
                    text: Status.meridiem
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(14)
                    font.weight: Font.Medium
                }
            }
            Text {
                text: Status.day + ", " + Status.date
                color: DeckUi.dim
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12.5)
            }
        }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: DeckUi.f(18)
            spacing: DeckUi.f(7)
            visible: Status.hasBattery
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Sh.batteryGlyph(Status.pct, Status.charging)
                color: Status.charging ? DeckUi.good : Status.low ? DeckUi.danger : DeckUi.text
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(15)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.pct + "%"
                color: Status.low ? DeckUi.danger : DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12.5)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Status.batteryNote.length > 0
                text: Status.batteryNote
                color: DeckUi.dim
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(11.5)
            }
        }

        // Flags for what is on: Focus, recording.
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: DeckUi.f(18)
            spacing: DeckUi.f(10)
            Text {
                visible: Notifications.dnd
                text: Sh.icBellOff
                color: DeckUi.text
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
            Text {
                visible: Capture.recording
                text: Sh.icRecord
                color: DeckUi.danger
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
        }
    }

    CalendarCard {
        id: calendar
        focused: DeckUi.zone === "calendar"
        width: col.innerW
        height: col.height - DeckUi.f(150) - col.spacing
        visible: DeckUi.calendarOpen
    }

    Card {
        id: media
        width: col.innerW
        visible: !DeckUi.calendarOpen
        height: col.height - DeckUi.f(150) - tiles.height - col.spacing * 2
        focused: DeckUi.zone === "media"

        readonly property var p: Status.player
        property int btn: 1   // keyboard: 0 prev · 1 play · 2 next

        function act(i) {
            if (!media.p) return
            if (i === 0 && media.p.canGoPrevious) media.p.previous()
            else if (i === 1 && media.p.canTogglePlaying) media.p.togglePlaying()
            else if (i === 2 && media.p.canGoNext) media.p.next()
        }

        Connections {
            target: DeckUi
            function onNav(key) {
                if (DeckUi.zone !== "media") return
                if (key === Qt.Key_Up) { DeckUi.go("up"); return }
                if (key === Qt.Key_Down) { DeckUi.go("down"); return }
                if (!media.p) { if (key === Qt.Key_Right) DeckUi.go("right"); return }
                if (key === Qt.Key_Left)  media.btn = Math.max(0, media.btn - 1)
                if (key === Qt.Key_Right) { if (media.btn === 2) DeckUi.go("right"); else media.btn++ }
                if (key === Qt.Key_Return || key === Qt.Key_Enter) media.act(media.btn)
            }
        }

        // Mpris doesn't push position; poll while visible and playing.
        Timer {
            interval: 1000
            repeat: true
            running: media.p !== null && Status.playing && Sh.deckShown
            onTriggered: media.p.positionChanged()
        }

        function clock(s) {
            s = Math.max(0, Math.floor(s))
            return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
        }

        Caption {
            id: mediaCap
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
            text: "Now playing"
            trailing: media.p ? media.p.identity : ""
        }

        Text {
            anchors.centerIn: parent
            visible: media.p === null
            text: "Nothing playing"
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12)
        }

        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: mediaCap.bottom }
            anchors.margins: DeckUi.f(16)
            anchors.topMargin: DeckUi.f(12)
            visible: media.p !== null

            ClippingRectangle {
                id: art
                // As large as the row above the transport allows.
                height: Math.min(DeckUi.f(68), parent.height - transport.height - DeckUi.f(10)); width: height
                radius: DeckUi.innerRadius
                color: DeckUi.graphite
                Text {
                    anchors.centerIn: parent
                    text: Sh.icMusic
                    color: DeckUi.faint
                    font.family: Sh.iconFont
                    font.pixelSize: DeckUi.f(18)
                }
                Image {
                    anchors.fill: parent
                    source: media.p ? media.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: DeckUi.f(136); sourceSize.height: DeckUi.f(136)
                }
            }
            Column {
                anchors.left: art.right
                anchors.leftMargin: DeckUi.f(12)
                anchors.right: parent.right
                anchors.verticalCenter: art.verticalCenter
                spacing: DeckUi.f(3)
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: media.p ? media.p.trackTitle : ""
                    color: DeckUi.text
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(13)
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: media.p ? media.p.trackArtist : ""
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(11.5)
                }
            }

            Row {
                id: transport
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: DeckUi.f(4)
                Button {
                    width: DeckUi.f(30); implicitHeight: DeckUi.f(28)
                    glyph: Sh.icSkipBack
                    glyphSize: DeckUi.f(12)
                    selected: media.focused && media.btn === 0
                    onClicked: media.act(0)
                }
                Button {
                    width: DeckUi.f(30); implicitHeight: DeckUi.f(28)
                    glyph: Status.playing ? Sh.icPause : Sh.icPlay
                    glyphSize: DeckUi.f(12)
                    selected: media.focused && media.btn === 1
                    onClicked: media.act(1)
                }
                Button {
                    width: DeckUi.f(30); implicitHeight: DeckUi.f(28)
                    glyph: Sh.icSkipForward
                    glyphSize: DeckUi.f(12)
                    selected: media.focused && media.btn === 2
                    onClicked: media.act(2)
                }
            }

            Text {
                id: remain
                anchors.right: parent.right
                anchors.verticalCenter: transport.verticalCenter
                visible: seekTrack.len > 0
                text: media.p ? "-" + media.clock(seekTrack.len - media.p.position) : ""
                color: DeckUi.faint
                font.family: DeckUi.mono
                font.pixelSize: DeckUi.f(10.5)
            }
            Rectangle {
                id: seekTrack
                anchors.left: transport.right
                anchors.leftMargin: DeckUi.f(12)
                anchors.right: remain.visible ? remain.left : parent.right
                anchors.rightMargin: remain.visible ? DeckUi.f(10) : 0
                anchors.verticalCenter: transport.verticalCenter
                height: DeckUi.f(3)
                radius: height / 2
                color: DeckUi.line
                readonly property real len: media.p ? media.p.length : 0
                Rectangle {
                    width: seekTrack.len > 0 ? parent.width * Math.min(1, media.p.position / seekTrack.len) : 0
                    height: parent.height
                    radius: height / 2
                    color: DeckUi.accent
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -DeckUi.f(8)
                    enabled: media.p !== null && media.p.canSeek && seekTrack.len > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => media.p.position =
                        Math.max(0, Math.min(1, (m.x - DeckUi.f(8)) / seekTrack.width)) * seekTrack.len
                }
            }
        }
    }

    // System tiles
    Grid {
        id: tiles
        visible: !DeckUi.calendarOpen
        columns: 2
        spacing: DeckUi.f(12)
        width: col.innerW
        readonly property real tw: (col.innerW - spacing) / 2
        readonly property real th: tiles.tw   // square; now playing takes what is left

        // Keyboard: ←→↑↓ move between tiles, Enter flips one.
        Connections {
            target: DeckUi
            function onNav(key) {
                if (DeckUi.zone !== "tiles") return
                const i = DeckUi.tile, left = i % 2 === 0, top = i < 2
                if (key === Qt.Key_Left && !left) DeckUi.tile = i - 1
                if (key === Qt.Key_Right) { if (left) DeckUi.tile = i + 1; else DeckUi.go("right") }
                if (key === Qt.Key_Up) { if (top) DeckUi.go("up"); else DeckUi.tile = i - 2 }
                if (key === Qt.Key_Down && top) DeckUi.tile = i + 2
                if (key === Qt.Key_Return || key === Qt.Key_Enter) SysStats.flip(["cpu", "mem", "gpu", "temp"][DeckUi.tile])
            }
        }

        component Tile: Card {
            id: tile
            property int index
            property string key
            property string glyph: ""
            property string label: ""
            property string value: ""
            property real level: 0
            property real hot: 0.9      // level at which the ring turns red
            property int views: 1       // how many views it flips between
            property int view: 0
            readonly property color tint: tile.level >= tile.hot ? DeckUi.danger : DeckUi.accent
            width: tiles.tw
            height: tiles.th
            border.width: 0   // the ring is the edge
            focused: DeckUi.zone === "tiles" && DeckUi.tile === tile.index

            property real shown: Math.max(0, Math.min(1, tile.level))
            Behavior on shown { Anim { duration: Motion.slow } }

            // Rounded-square ring tracing the tile from top centre, clockwise: the perimeter is
            // laid out once per size, and each update only cuts it to length.
            readonly property real lw: DeckUi.f(3)
            readonly property var perimeter: {
                const s = lw / 2, x0 = s, y0 = s, w = width - lw, h = height - lw
                const r = Math.max(1, DeckUi.radius - s), pts = [], H = Math.PI / 2
                const arc = (cx, cy, a0) => { for (let k = 1; k <= 10; k++) { const a = a0 + H * k / 10; pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]) } }
                pts.push([x0 + w / 2, y0], [x0 + w - r, y0]); arc(x0 + w - r, y0 + r, -H)
                pts.push([x0 + w, y0 + h - r]); arc(x0 + w - r, y0 + h - r, 0)
                pts.push([x0 + r, y0 + h]); arc(x0 + r, y0 + h - r, H)
                pts.push([x0, y0 + r]); arc(x0 + r, y0 + r, 2 * H)
                pts.push([x0 + w / 2, y0])
                const len = [0]
                for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
                return { pts: pts, len: len }
            }
            readonly property var arcPts: {
                const P = tile.perimeter, want = P.len[P.len.length - 1] * tile.shown, out = [Qt.point(P.pts[0][0], P.pts[0][1])]
                for (let i = 1; i < P.pts.length; i++) {
                    if (P.len[i] <= want) { out.push(Qt.point(P.pts[i][0], P.pts[i][1])); continue }
                    const f = (want - P.len[i - 1]) / (P.len[i] - P.len[i - 1])
                    out.push(Qt.point(P.pts[i - 1][0] + (P.pts[i][0] - P.pts[i - 1][0]) * f, P.pts[i - 1][1] + (P.pts[i][1] - P.pts[i - 1][1]) * f))
                    break
                }
                return out
            }

            Rectangle {
                anchors.fill: parent
                radius: DeckUi.radius
                color: "transparent"
                border.width: tile.lw
                border.color: tile.focused ? DeckUi.focusRim : DeckUi.rim
            }
            Shape {
                anchors.fill: parent
                visible: tile.shown > 0.002
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: tile.tint
                    strokeWidth: tile.lw
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: tile.arcPts }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: DeckUi.f(3)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.glyph
                    color: tile.level >= tile.hot ? DeckUi.danger : DeckUi.dim
                    font.family: Sh.iconFont
                    font.pixelSize: DeckUi.f(18)
                    bottomPadding: DeckUi.f(3)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.value
                    color: DeckUi.text
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(20)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, tiles.tw - DeckUi.f(20))
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.label
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(10.5)
                }
            }
            // One dot per view when the tile flips.
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: DeckUi.f(10) }
                spacing: DeckUi.f(4)
                visible: tile.views > 1
                Repeater {
                    model: tile.views
                    Rectangle {
                        required property int index
                        width: DeckUi.f(4); height: width; radius: width / 2
                        color: index === tile.view ? DeckUi.dim : Qt.rgba(1, 1, 1, 0.14)
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: tile.views > 1
                cursorShape: tile.views > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { DeckUi.tile = tile.index; SysStats.flip(tile.key) }
            }
        }

        // CPU: load, or the average clock against the highest boost.
        Tile {
            index: 0; key: "cpu"; views: 2
            view: SysStats.views.cpu
            glyph: Sh.icCpu
            label: view ? "Clock" : "CPU"
            value: view ? (SysStats.mhz / 1000).toFixed(1) + " GHz" : Math.round(SysStats.cpu * 100) + "%"
            level: view ? (SysStats.maxMhz ? SysStats.mhz / SysStats.maxMhz : 0) : SysStats.cpu
            hot: view ? 2 : 0.9
        }
        // Memory: RAM, or the GPU's (dedicated plus shared on an iGPU).
        Tile {
            readonly property var g: SysStats.vramGpu
            index: 1; key: "mem"; views: g ? 2 : 1
            view: g ? SysStats.views.mem : 0
            glyph: Sh.icRam
            label: view ? "VRAM" : "Memory"
            value: view ? g.memUsed.toFixed(1) + " GB"
                 : SysStats.memTotal > 0 ? Math.round(SysStats.memUsed / SysStats.memTotal * 100) + "%" : "–"
            level: view ? g.memUsed / g.memTotal : SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
        }
        // GPU: each one in turn. A sleeping GPU says so rather than being woken to ask.
        Tile {
            readonly property var g: SysStats.gpu
            index: 2; key: "gpu"; views: SysStats.gpus.length
            view: SysStats.gpuIndex
            glyph: Sh.icGauge
            label: g ? g.name : "GPU"
            value: !g ? "–" : g.asleep ? "Asleep" : g.busy >= 0 ? Math.round(g.busy * 100) + "%" : "On"
            level: g && !g.asleep ? Math.max(0, g.busy) : 0
        }
        // Temperature, or power draw: red when it runs well above its recent normal.
        Tile {
            index: 3; key: "temp"; views: Power.available ? 2 : 1
            view: Power.available ? SysStats.views.temp : 0
            glyph: view ? Sh.icBolt : Sh.icThermo
            label: view ? Power.source : "Temp"
            value: view ? Power.watts.toFixed(1) + " W" : SysStats.temp >= 0 ? Math.round(SysStats.temp) + "°" : "–"
            level: view ? Power.watts / Math.max(30, ...Power.hist) : SysStats.temp >= 0 ? (SysStats.temp - 30) / 65 : 0
            hot: view ? (Power.peaking ? 0 : 2) : (85 - 30) / 65   // 85°C
        }
    }
}
