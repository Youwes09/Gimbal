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
                    color: Theme.fg
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(50)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: clockText.baseline
                    text: Status.meridiem
                    color: Theme.accent
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(14)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                }
            }
            Text {
                text: Status.day + "  ·  " + Status.date
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: DeckUi.f(11)
                font.weight: Font.Medium
                font.letterSpacing: 2.2
                font.capitalization: Font.AllUppercase
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
                color: Status.charging ? Theme.accent : Status.low ? Theme.error : Theme.fg
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(15)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.pct + "%"
                color: Status.low ? Theme.error : Theme.fg
                font.family: Sh.font
                font.pixelSize: DeckUi.f(12.5)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Status.batteryNote.length > 0
                text: Status.batteryNote
                color: DeckUi.dim
                font.family: Sh.font
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
                color: Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
            Text {
                visible: DeckUi.stayAwake
                text: Sh.icEye
                color: Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
            Text {
                visible: Capture.recording
                text: Sh.icRecord
                color: Theme.error
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
        }
    }

    // ── now playing ─────────────────────────────────────────────────────
    Card {
        id: media
        width: col.innerW
        height: DeckUi.f(172)
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
                if (key === Qt.Key_Left)  media.btn = Math.max(0, media.btn - 1)
                if (key === Qt.Key_Right) media.btn = Math.min(2, media.btn + 1)
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
            anchors.verticalCenterOffset: DeckUi.f(8)
            visible: media.p === null
            spacing: DeckUi.f(6)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Sh.icMusic
                color: DeckUi.faint
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(22)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: DeckUi.f(12)
            }
        }

        Item {
            anchors { left: parent.left; right: parent.right; top: mediaCap.bottom; bottom: parent.bottom }
            anchors.margins: DeckUi.f(16)
            anchors.topMargin: DeckUi.f(12)
            visible: media.p !== null

            ClippingRectangle {
                id: art
                width: DeckUi.f(60); height: width
                radius: DeckUi.f(9)
                color: DeckUi.well
                Image {
                    anchors.fill: parent
                    source: media.p ? media.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: DeckUi.f(120); sourceSize.height: DeckUi.f(120)
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
                    color: Theme.fg
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(14)
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: media.p ? media.p.trackArtist : ""
                    color: DeckUi.dim
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(12)
                }
            }

            Rectangle {
                id: seekTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: art.bottom
                anchors.topMargin: DeckUi.f(12)
                height: DeckUi.f(3)
                radius: height / 2
                color: DeckUi.line
                readonly property real len: media.p ? media.p.length : 0
                Rectangle {
                    width: seekTrack.len > 0 ? parent.width * Math.min(1, media.p.position / seekTrack.len) : 0
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -DeckUi.f(6)
                    enabled: media.p !== null && media.p.canSeek && seekTrack.len > 0
                    onClicked: (m) => media.p.position =
                        Math.max(0, Math.min(1, (m.x - DeckUi.f(6)) / seekTrack.width)) * seekTrack.len
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: DeckUi.f(10)
                Button {
                    width: DeckUi.f(40); implicitHeight: DeckUi.f(30)
                    glyph: Sh.icSkipBack
                    glyphSize: DeckUi.f(13)
                    selected: media.focused && media.btn === 0
                    onClicked: media.act(0)
                }
                Button {
                    width: DeckUi.f(52); implicitHeight: DeckUi.f(30)
                    glyph: Status.playing ? Sh.icPause : Sh.icPlay
                    glyphSize: DeckUi.f(13)
                    on: !(media.focused && media.btn === 1)
                    selected: media.focused && media.btn === 1
                    onClicked: media.act(1)
                }
                Button {
                    width: DeckUi.f(40); implicitHeight: DeckUi.f(30)
                    glyph: Sh.icSkipForward
                    glyphSize: DeckUi.f(13)
                    selected: media.focused && media.btn === 2
                    onClicked: media.act(2)
                }
            }
        }
    }

    // ── system tiles ────────────────────────────────────────────────────
    Grid {
        id: tiles
        columns: 2
        spacing: DeckUi.f(12)
        width: col.innerW
        readonly property real tw: (col.innerW - spacing) / 2
        readonly property real th: (col.height - DeckUi.f(150) - DeckUi.f(172) - col.spacing * 2 - spacing) / 2

        component Tile: Card {
            id: tile
            property string glyph: ""
            property string label: ""
            property string value: ""
            property string sub: ""
            property real level: 0
            property color tint: Theme.accent
            property var history: []
            width: tiles.tw
            height: tiles.th

            // Sparkline of the last minute, drawn behind the numbers.
            Canvas {
                id: spark
                visible: tile.history.length > 1
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                height: parent.height * 0.5
                property var pts: tile.history
                onPtsChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const n = pts.length
                    if (n < 2) return
                    const w = width, h = height, dx = w / 39
                    ctx.beginPath()
                    ctx.moveTo(w - (n - 1) * dx, h)
                    for (let i = 0; i < n; i++) ctx.lineTo(w - (n - 1 - i) * dx, h - pts[i] * h * 0.9)
                    ctx.lineTo(w, h)
                    ctx.closePath()
                    const g = ctx.createLinearGradient(0, 0, 0, h)
                    g.addColorStop(0, Qt.alpha(tile.tint, 0.28))
                    g.addColorStop(1, Qt.alpha(tile.tint, 0.0))
                    ctx.fillStyle = g
                    ctx.fill()
                }
            }

            Text {
                anchors { left: parent.left; top: parent.top; margins: DeckUi.f(12) }
                text: tile.glyph
                color: tile.tint
                font.family: Sh.iconFont
                font.pixelSize: DeckUi.f(14)
            }
            Text {
                anchors { right: parent.right; top: parent.top; margins: DeckUi.f(12) }
                text: tile.label
                color: DeckUi.faint
                font.family: Sh.font
                font.pixelSize: DeckUi.f(10)
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; margins: DeckUi.f(12) }
                anchors.bottomMargin: DeckUi.f(14)
                spacing: 0
                Text {
                    text: tile.value
                    color: Theme.fg
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(21)
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: tile.sub.length > 0
                    text: tile.sub
                    color: DeckUi.dim
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(10.5)
                }
            }
            Rectangle {
                visible: tile.history.length === 0
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(12) }
                anchors.bottomMargin: DeckUi.f(8)
                height: 2
                radius: 1
                color: DeckUi.line
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, tile.level))
                    height: parent.height
                    radius: 1
                    color: tile.tint
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }
        }

        Tile {
            glyph: Sh.icCpu
            label: "CPU"
            value: Math.round(SysStats.cpu * 100) + "%"
            history: SysStats.cpuHist
            tint: Theme.accent
        }
        Tile {
            glyph: Sh.icRam
            label: "RAM"
            value: SysStats.memUsed.toFixed(1) + "G"
            sub: "of " + Math.round(SysStats.memTotal) + "G"
            level: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
            tint: Theme.second
        }
        Tile {
            glyph: Sh.icGauge
            label: "GPU"
            value: SysStats.gpu >= 0 ? Math.round(SysStats.gpu * 100) + "%" : "–"
            level: Math.max(0, SysStats.gpu)
            tint: Theme.third
        }
        Tile {
            glyph: Sh.icThermo
            label: "TEMP"
            value: SysStats.temp >= 0 ? Math.round(SysStats.temp) + "°" : "–"
            sub: "CPU package"
            level: SysStats.temp >= 0 ? (SysStats.temp - 30) / 65 : 0
            tint: SysStats.temp >= 85 ? Theme.error : Theme.contrast
        }
    }
}
