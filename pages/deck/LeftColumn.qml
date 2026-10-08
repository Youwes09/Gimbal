import QtQuick
import Quickshell.Widgets
import "root:/modules"

// At a glance: clock, now playing, live system tiles.
Column {
    id: col
    spacing: DeckUi.f(12)

    readonly property real innerW: col.width

    // ── clock ───────────────────────────────────────────────────────────
    Card {
        width: col.innerW
        height: DeckUi.f(150)

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

        // Status flags in the corner: only what's actually on.
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
                visible: DeckUi.stayAwake
                text: Sh.icEye
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

    // ── now playing ─────────────────────────────────────────────────────
    Card {
        id: media
        width: col.innerW
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

        Caption {
            id: mediaCap
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
            text: "Now playing"
            trailing: media.p ? media.p.identity : ""
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: DeckUi.f(10)
            visible: media.p === null
            spacing: DeckUi.f(6)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Sh.icMusic
                color: DeckUi.faint
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(20)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: DeckUi.faint
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12)
            }
        }

        // Flat transport key: just the glyph, filled only on hover or keyboard focus.
        component Ctl: Rectangle {
            id: c
            property string glyph: ""
            property int i: 0
            property real size: DeckUi.f(15)
            readonly property bool sel: media.focused && media.btn === c.i
            height: DeckUi.f(32)
            radius: DeckUi.innerRadius
            color: c.sel ? DeckUi.sel : cma.containsMouse ? DeckUi.hover : "transparent"
            border.width: 1
            border.color: c.sel ? DeckUi.selRim : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: c.glyph
                color: DeckUi.text
                font.family: Sh.iconFont
                font.pixelSize: c.size
            }
            MouseArea {
                id: cma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: media.act(c.i)
            }
        }

        // Cover as tall as the body allows; track and transport centred beside it.
        Item {
            id: body
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: mediaCap.bottom }
            anchors.margins: DeckUi.f(16)
            anchors.topMargin: DeckUi.f(12)
            visible: media.p !== null

            ClippingRectangle {
                id: art
                height: body.height
                width: height
                radius: DeckUi.innerRadius
                color: DeckUi.graphite
                Text {
                    anchors.centerIn: parent
                    text: Sh.icMusic
                    color: DeckUi.faint
                    font.family: Sh.iconFont
                    font.pixelSize: DeckUi.f(22)
                }
                Image {
                    anchors.fill: parent
                    source: media.p ? media.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: art.width * 2; sourceSize.height: art.height * 2
                }
            }

            Item {
                anchors { left: art.right; leftMargin: DeckUi.f(12); right: parent.right; top: parent.top; bottom: parent.bottom }

                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: DeckUi.f(4) }
                    spacing: DeckUi.f(3)
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: media.p ? media.p.trackTitle : ""
                        color: DeckUi.text
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(13.5)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: media.p ? media.p.trackArtist : ""
                        color: DeckUi.dim
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(12)
                    }
                }

                Rectangle {
                    id: seekTrack
                    anchors { left: parent.left; right: parent.right; bottom: transport.top; margins: DeckUi.f(6); bottomMargin: DeckUi.f(8) }
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
                        anchors.margins: -DeckUi.f(6)
                        enabled: media.p !== null && media.p.canSeek && seekTrack.len > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (m) => media.p.position =
                            Math.max(0, Math.min(1, (m.x - DeckUi.f(6)) / seekTrack.width)) * seekTrack.len
                    }
                }

                Row {
                    id: transport
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    readonly property real kw: width / 3
                    Ctl { width: transport.kw; i: 0; glyph: Sh.icSkipBack }
                    Ctl { width: transport.kw; i: 1; glyph: Status.playing ? Sh.icPause : Sh.icPlay; size: DeckUi.f(18) }
                    Ctl { width: transport.kw; i: 2; glyph: Sh.icSkipForward }
                }
            }
        }
    }

    // ── system tiles: the same ring for each, icon and value in the middle ─
    Grid {
        id: tiles
        columns: 2
        spacing: DeckUi.f(12)
        width: col.innerW
        readonly property real tw: (col.innerW - spacing) / 2
        readonly property real th: tiles.tw * 0.8   // now playing takes what is left

        component Tile: Card {
            id: tile
            property string glyph: ""
            property string label: ""
            property string value: ""
            property real level: 0
            property real hot: 0.9      // level at which the ring turns red
            readonly property color tint: tile.level >= tile.hot ? DeckUi.danger : DeckUi.accent
            width: tiles.tw
            height: tiles.th
            border.width: 0   // the ring is the edge

            property real shown: Math.max(0, Math.min(1, tile.level))
            Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            onShownChanged: ring.requestPaint()
            onTintChanged: ring.requestPaint()

            // Rounded-square progress ring tracing the tile, starting top centre, clockwise.
            Canvas {
                id: ring
                anchors.fill: parent
                anchors.margins: 0
                readonly property real lw: DeckUi.f(3)
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const s = lw / 2, x0 = s, y0 = s, w = width - lw, h = height - lw
                    const r = Math.max(1, DeckUi.radius - s)
                    ctx.lineWidth = lw
                    ctx.lineCap = "round"

                    ctx.strokeStyle = DeckUi.rim
                    ctx.beginPath()
                    ctx.roundedRect(x0, y0, w, h, r, r)
                    ctx.stroke()

                    let left = (2 * (w + h) - 8 * r + 2 * Math.PI * r) * tile.shown
                    if (left <= 0) return
                    const H = Math.PI / 2
                    // [kind, length, x0/cx, y0/cy, x1/startAngle, y1]
                    const segs = [
                        ["l", w / 2 - r, x0 + w / 2, y0, x0 + w - r, y0],
                        ["a", H * r, x0 + w - r, y0 + r, -H],
                        ["l", h - 2 * r, x0 + w, y0 + r, x0 + w, y0 + h - r],
                        ["a", H * r, x0 + w - r, y0 + h - r, 0],
                        ["l", w - 2 * r, x0 + w - r, y0 + h, x0 + r, y0 + h],
                        ["a", H * r, x0 + r, y0 + h - r, H],
                        ["l", h - 2 * r, x0, y0 + h - r, x0, y0 + r],
                        ["a", H * r, x0 + r, y0 + r, 2 * H],
                        ["l", w / 2 - r, x0 + r, y0, x0 + w / 2, y0]
                    ]
                    ctx.strokeStyle = tile.tint
                    ctx.beginPath()
                    ctx.moveTo(x0 + w / 2, y0)
                    for (const g of segs) {
                        const f = Math.min(1, left / g[1])
                        if (g[0] === "l") ctx.lineTo(g[2] + (g[4] - g[2]) * f, g[3] + (g[5] - g[3]) * f)
                        else ctx.arc(g[2], g[3], r, g[4], g[4] + H * f, false)
                        left -= g[1]
                        if (left <= 0) break
                    }
                    ctx.stroke()
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
                    text: tile.label
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(11)
                    font.weight: Font.Medium
                }
            }
        }

        Tile {
            glyph: Sh.icCpu
            label: "CPU"
            value: Math.round(SysStats.cpu * 100) + "%"
            level: SysStats.cpu
        }
        Tile {
            glyph: Sh.icRam
            label: "Memory"
            value: SysStats.memTotal > 0 ? Math.round(SysStats.memUsed / SysStats.memTotal * 100) + "%" : "–"
            level: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
        }
        Tile {
            glyph: Sh.icGauge
            label: "GPU"
            value: SysStats.gpu >= 0 ? Math.round(SysStats.gpu * 100) + "%" : "–"
            level: Math.max(0, SysStats.gpu)
        }
        Tile {
            glyph: Sh.icThermo
            label: "Temp"
            value: SysStats.temp >= 0 ? Math.round(SysStats.temp) + "°" : "–"
            level: SysStats.temp >= 0 ? (SysStats.temp - 30) / 65 : 0
            hot: (85 - 30) / 65   // 85°C
        }
    }
}
