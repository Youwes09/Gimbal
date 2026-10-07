import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/modules"

// Game-bar style dashboard laid out around the launcher's search panel:
// media | search + controls | system & power, wallpapers along the bottom.
Item {
    id: root
    anchors.fill: parent

    required property Item panel   // the launcher's search panel, same coordinate space
    property real t: 1             // window reveal 0..1

    readonly property real uiScale: 1.12
    function f(px) { return Sh.fs(px * root.uiScale) }

    readonly property color cPanel: Qt.alpha(Theme.bg, 0.97)
    readonly property color cRim:   Qt.alpha(Theme.fg, 0.1)
    readonly property color cSheen: Qt.alpha(Theme.fg, 0.06)
    readonly property color cDim:   Qt.alpha(Theme.fg, 0.55)
    readonly property color cFaint: Qt.alpha(Theme.fg, 0.1)

    readonly property real gap:   f(24)
    readonly property real pad:   f(16)
    readonly property real barH:  f(58)
    readonly property real ctrlH: f(112)
    readonly property real sideW: f(340)
    readonly property real sideH: barH + gap + ctrlH
    readonly property real stripH: f(150)

    readonly property real pX: panel.x
    readonly property real pY: panel.y
    readonly property real pW: panel.width

    // ── building blocks ─────────────────────────────────────────────────

    component Card: Rectangle {
        radius: root.f(16)
        color: root.cPanel
        border.width: 1
        border.color: root.cRim
        transform: Translate { y: (1 - root.t) * root.f(14) }
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.f(16) }
            anchors.topMargin: 1
            height: 1
            color: root.cSheen
        }
    }

    component Caption: Text {
        color: root.cDim
        font.family: Sh.font
        font.pixelSize: root.f(11)
        font.weight: Font.Medium
        font.letterSpacing: 2
        font.capitalization: Font.AllUppercase
    }

    component Glyph: Text {
        font.family: Sh.iconFont
        color: root.cDim
    }

    component Pill: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        property bool on: false
        property color tint: Theme.accent
        signal clicked()
        height: root.f(38)
        radius: root.f(10)
        color: pill.on ? Qt.alpha(pill.tint, 0.16)
             : pillMa.containsMouse ? Qt.alpha(Theme.fg, 0.08) : Qt.alpha(Theme.fg, 0.035)
        border.width: 1
        border.color: pill.on ? Qt.alpha(pill.tint, 0.45) : Qt.alpha(Theme.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: root.f(7)
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.glyph
                color: pill.on ? pill.tint : Theme.fg
                font.pixelSize: root.f(15)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.label.length > 0
                text: pill.label
                color: pill.on ? pill.tint : Theme.fg
                font.family: Sh.font
                font.pixelSize: root.f(12)
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component Slider: Item {
        id: sl
        property real value: 0
        property string glyph: ""
        property bool muted: false
        signal moved(real v)
        signal glyphClicked()
        height: root.f(30)

        Glyph {
            id: slGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.f(22)
            text: sl.glyph
            color: sl.muted ? Theme.error : Theme.fg
            font.pixelSize: root.f(16)
            MouseArea { anchors.fill: parent; anchors.margins: -root.f(6); onClicked: sl.glyphClicked() }
        }
        Text {
            id: slPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.f(38)
            horizontalAlignment: Text.AlignRight
            text: Math.round(sl.value * 100)
            color: root.cDim
            font.family: Sh.font
            font.pixelSize: root.f(12)
        }
        Item {
            id: track
            anchors.left: slGlyph.right
            anchors.right: slPct.left
            anchors.leftMargin: root.f(10)
            anchors.rightMargin: root.f(10)
            anchors.verticalCenter: parent.verticalCenter
            height: root.f(6)

            Rectangle { anchors.fill: parent; radius: height / 2; color: root.cFaint }
            Rectangle {
                width: Math.max(height, track.width * Math.max(0, Math.min(1, sl.value)))
                height: parent.height
                radius: height / 2
                color: sl.muted ? Qt.alpha(Theme.fg, 0.3) : Theme.accent
            }
            Rectangle {
                width: root.f(14); height: width; radius: width / 2
                x: track.width * Math.max(0, Math.min(1, sl.value)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                scale: slMa.pressed ? 1.2 : slMa.containsMouse ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: slMa
                anchors.fill: parent
                anchors.margins: -root.f(10)
                hoverEnabled: true
                preventStealing: true
                function _at(x) { return Math.max(0, Math.min(1, (x - root.f(10)) / track.width)) }
                onPressed: (m) => sl.moved(_at(m.x))
                onPositionChanged: (m) => { if (pressed) sl.moved(_at(m.x)) }
            }
        }
    }

    component Meter: Item {
        id: mt
        property string label: ""
        property real value: 0
        property string text: ""
        property color tint: Theme.accent
        height: root.f(26)
        Caption {
            id: mtLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.f(42)
            text: mt.label
        }
        Text {
            id: mtVal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.f(92)
            horizontalAlignment: Text.AlignRight
            text: mt.text
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: root.f(12)
        }
        Rectangle {
            anchors.left: mtLabel.right
            anchors.right: mtVal.left
            anchors.rightMargin: root.f(10)
            anchors.verticalCenter: parent.verticalCenter
            height: root.f(5)
            radius: height / 2
            color: root.cFaint
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, mt.value))
                height: parent.height
                radius: height / 2
                color: mt.tint
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    function _clock(s) {
        if (!(s > 0)) return "0:00"
        s = Math.floor(s)
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ── media ───────────────────────────────────────────────────────────

    Card {
        id: media
        x: root.pX - root.gap - width
        y: root.pY
        width: root.sideW
        height: root.sideH

        readonly property var p: Status.player

        // Mpris doesn't push position; poll it while visible and playing.
        Timer {
            interval: 1000
            repeat: true
            running: media.p !== null && Status.playing && Sh.launcherShown && Sh.dash
            onTriggered: media.p.positionChanged()
        }

        Column {
            anchors.centerIn: parent
            visible: media.p === null
            spacing: root.f(8)
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Sh.icMusic
                font.pixelSize: root.f(26)
                color: Qt.alpha(Theme.fg, 0.25)
            }
            Caption { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing playing" }
        }

        Item {
            anchors.fill: parent
            anchors.margins: root.pad
            visible: media.p !== null

            Row {
                id: mediaTop
                width: parent.width
                spacing: root.f(14)

                ClippingRectangle {
                    width: root.f(84); height: width
                    radius: root.f(10)
                    color: root.cFaint
                    Image {
                        anchors.fill: parent
                        source: media.p ? media.p.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: root.f(168); sourceSize.height: root.f(168)
                    }
                }
                Column {
                    width: parent.width - root.f(84) - root.f(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.f(4)
                    Caption {
                        width: parent.width
                        elide: Text.ElideRight
                        text: media.p ? media.p.identity : ""
                        font.pixelSize: root.f(10)
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: media.p ? media.p.trackTitle : ""
                        color: Theme.fg
                        font.family: Sh.font
                        font.pixelSize: root.f(15)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: media.p ? media.p.trackArtist : ""
                        color: root.cDim
                        font.family: Sh.font
                        font.pixelSize: root.f(12)
                    }
                }
            }

            Item {
                id: seek
                anchors.top: mediaTop.bottom
                anchors.topMargin: root.f(14)
                width: parent.width
                height: root.f(16)
                readonly property real len: media.p ? media.p.length : 0
                readonly property real frac: seek.len > 0 ? Math.min(1, media.p.position / seek.len) : 0

                Text {
                    id: posText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._clock(media.p ? media.p.position : 0)
                    color: root.cDim
                    font.family: Sh.font
                    font.pixelSize: root.f(10)
                }
                Text {
                    id: lenText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._clock(seek.len)
                    color: root.cDim
                    font.family: Sh.font
                    font.pixelSize: root.f(10)
                }
                Rectangle {
                    id: seekTrack
                    anchors.left: posText.right
                    anchors.right: lenText.left
                    anchors.leftMargin: root.f(8)
                    anchors.rightMargin: root.f(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.f(4)
                    radius: height / 2
                    color: root.cFaint
                    Rectangle {
                        width: parent.width * seek.frac
                        height: parent.height
                        radius: height / 2
                        color: Theme.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.f(8)
                        enabled: media.p !== null && media.p.canSeek && seek.len > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: (m) => {
                            media.p.position = Math.max(0, Math.min(1, (m.x - root.f(8)) / seekTrack.width)) * seek.len
                        }
                    }
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.f(18)

                Pill {
                    width: root.f(44); height: root.f(36)
                    glyph: Sh.icSkipBack
                    onClicked: if (media.p && media.p.canGoPrevious) media.p.previous()
                }
                Pill {
                    width: root.f(56); height: root.f(36)
                    glyph: Status.playing ? Sh.icPause : Sh.icPlay
                    on: true
                    onClicked: if (media.p && media.p.canTogglePlaying) media.p.togglePlaying()
                }
                Pill {
                    width: root.f(44); height: root.f(36)
                    glyph: Sh.icSkipForward
                    onClicked: if (media.p && media.p.canGoNext) media.p.next()
                }
            }
        }
    }

    // ── controls (under the search bar) ─────────────────────────────────

    Card {
        id: controls
        x: root.pX
        y: root.pY + root.barH + root.gap
        width: root.pW
        height: root.ctrlH

        // Brightness shells out per change; coalesce drags to one call per frame-ish.
        property real _briWant: -1
        Timer {
            id: briThrottle
            interval: 60
            onTriggered: if (controls._briWant >= 0) { Brightness.set(controls._briWant); controls._briWant = -1 }
        }

        Column {
            anchors.fill: parent
            anchors.margins: root.pad
            spacing: root.f(12)

            Row {
                width: parent.width
                spacing: root.f(28)
                Slider {
                    width: (parent.width - parent.spacing) / 2
                    glyph: Audio.muted || Audio.volume === 0 ? Sh.icVolumeMute
                         : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh
                    muted: Audio.muted
                    value: Audio.volume
                    onMoved: (v) => Audio.setVolume(v)
                    onGlyphClicked: Audio.toggleMute()
                }
                Slider {
                    width: (parent.width - parent.spacing) / 2
                    visible: Brightness.available
                    glyph: Sh.icSun
                    value: controls._briWant >= 0 ? controls._briWant : Brightness.pct
                    onMoved: (v) => { controls._briWant = v; if (!briThrottle.running) briThrottle.start() }
                }
            }

            Row {
                width: parent.width
                spacing: root.f(10)
                readonly property real w: (width - spacing * 2) / 3
                Pill {
                    width: parent.w
                    glyph: Sh.icMonitor
                    label: "Screenshot"
                    onClicked: Capture.shot("region")
                }
                Pill {
                    width: parent.w
                    glyph: Capture.recording ? Sh.icPause : Sh.icPlay
                    label: Capture.recording ? "Stop recording" : "Record"
                    on: Capture.recording
                    tint: Theme.error
                    onClicked: { if (!Capture.recording) Sh.closeLauncher(); Capture.recToggle() }
                }
                Pill {
                    width: parent.w
                    glyph: Notifications.dnd ? Sh.icBellOff : Sh.icBell
                    label: "Do Not Disturb"
                    on: Notifications.dnd
                    onClicked: Notifications.toggleDnd()
                }
            }
        }
    }

    // ── system + power ──────────────────────────────────────────────────

    Card {
        id: sys
        x: root.pX + root.pW + root.gap
        y: root.pY
        width: root.sideW
        height: root.sideH

        property string armed: ""
        Timer { id: disarm; interval: 3000; onTriggered: sys.armed = "" }
        function act(name) {
            if (name === "rest")    { Sh.rest(); return }
            if (name === "suspend") { Sh.closeLauncher(); Quickshell.execDetached(["systemctl", "suspend"]); return }
            // Reboot / shutdown need a second click.
            if (sys.armed !== name) { sys.armed = name; disarm.restart(); return }
            Quickshell.execDetached(["systemctl", name])
        }

        Column {
            anchors.fill: parent
            anchors.margins: root.pad
            spacing: root.f(6)

            Meter {
                width: parent.width
                label: "CPU"
                value: SysStats.cpu
                text: Math.round(SysStats.cpu * 100) + "%"
                tint: Theme.accent
            }
            Meter {
                width: parent.width
                label: "RAM"
                value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                text: SysStats.memUsed.toFixed(1) + " / " + Math.round(SysStats.memTotal) + " G"
                tint: Theme.second
            }
            Meter {
                width: parent.width
                visible: SysStats.gpu >= 0
                label: "GPU"
                value: Math.max(0, SysStats.gpu)
                text: Math.round(Math.max(0, SysStats.gpu) * 100) + "%"
                tint: Theme.third
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.pad
            spacing: root.f(8)

            Caption {
                text: sys.armed === "reboot"   ? "Click again to reboot"
                    : sys.armed === "poweroff" ? "Click again to shut down"
                    : powerRow.hover || "Power"
                color: sys.armed !== "" ? Theme.error : root.cDim
            }
            Row {
                id: powerRow
                width: parent.width
                spacing: root.f(8)
                property string hover: ""
                readonly property real w: (width - spacing * 3) / 4
                Repeater {
                    model: [
                        { id: "rest",     glyph: Sh.icLock,    label: "Rest" },
                        { id: "suspend",  glyph: Sh.icMoon,    label: "Suspend" },
                        { id: "reboot",   glyph: Sh.icRefresh, label: "Reboot" },
                        { id: "poweroff", glyph: Sh.icPower,   label: "Shut down" }
                    ]
                    Pill {
                        required property var modelData
                        width: powerRow.w
                        glyph: modelData.glyph
                        on: sys.armed === modelData.id
                        tint: Theme.error
                        onClicked: sys.act(modelData.id)
                        HoverHandler { onHoveredChanged: powerRow.hover = hovered ? modelData.label : "" }
                    }
                }
            }
        }
    }

    // ── wallpapers ──────────────────────────────────────────────────────

    Card {
        id: strip
        x: media.x
        y: root.pY + root.sideH + root.gap
        width: sys.x + sys.width - media.x
        height: root.stripH

        property int sel: Math.max(0, Wallpapers._idx())

        function apply() {
            const w = Wallpapers.list[strip.sel]
            if (w && w.path !== Wallpapers.current) Wallpapers.apply(w.path)
        }

        Connections {
            target: Sh
            function onDashStep(dir) {
                if (Wallpapers.list.length === 0) return
                strip.sel = (strip.sel + dir + Wallpapers.list.length) % Wallpapers.list.length
            }
            function onDashApply() { strip.apply() }
            function onLauncherShownChanged() {
                if (!Sh.launcherShown || !Sh.dash) return
                Wallpapers.rescan()
                strip.sel = Math.max(0, Wallpapers._idx())
                walls.positionViewAtIndex(strip.sel, ListView.Center)
            }
        }

        Caption {
            id: stripCap
            x: root.pad
            y: root.f(12)
            text: (Wallpapers.list[strip.sel] ? Wallpapers.list[strip.sel].name : "Wallpapers")
                  + "     ← → browse · enter apply"
        }

        ListView {
            id: walls
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.f(12)
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            height: root.f(100)
            orientation: ListView.Horizontal
            spacing: root.f(12)
            clip: true
            model: Wallpapers.list
            currentIndex: strip.sel
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - root.f(80)
            preferredHighlightEnd: width / 2 + root.f(80)
            highlightMoveDuration: 220
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: th
                required property var modelData
                required property int index
                readonly property bool isSel: index === strip.sel
                readonly property bool isCur: modelData.path === Wallpapers.current
                width: root.f(160)
                height: walls.height

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: root.f(3)
                    radius: root.f(10)
                    color: root.cFaint
                    scale: th.isSel ? 1 : thMa.containsMouse ? 0.97 : 0.94
                    opacity: th.isSel || thMa.containsMouse ? 1 : 0.6
                    Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + th.modelData.thumb
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: root.f(320)
                        onStatusChanged: if (status === Image.Error && !th.modelData.video)
                                             source = "file://" + th.modelData.path
                    }
                    Glyph {
                        visible: th.modelData.video
                        anchors { right: parent.right; bottom: parent.bottom; margins: root.f(6) }
                        text: Sh.icPlay
                        color: "white"
                        font.pixelSize: root.f(12)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.f(1)
                    radius: root.f(12)
                    color: "transparent"
                    border.width: 2
                    border.color: th.isSel ? Theme.accent : "transparent"
                }
                Rectangle {
                    visible: th.isCur
                    anchors { left: parent.left; top: parent.top; margins: root.f(9) }
                    width: root.f(8); height: width; radius: width / 2
                    color: Theme.accent
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.5)
                }
                MouseArea {
                    id: thMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { strip.sel = th.index; strip.apply() }
                }
            }
        }
    }
}
