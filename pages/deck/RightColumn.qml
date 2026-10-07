import QtQuick
import Quickshell.Services.Pipewire
import "root:/modules"

// Controls: quick toggles, then a mixer (output, mic, brightness, each app playing).
Column {
    id: col
    spacing: DeckUi.f(12)

    readonly property real quickH: DeckUi.f(232)

    // ── quick toggles ───────────────────────────────────────────────────
    Card {
        id: quick
        width: col.width
        height: col.quickH
        focused: DeckUi.zone === "quick"

        readonly property var items: [
            { glyph: Notifications.dnd ? Sh.icBellOff : Sh.icBell, label: "Focus",
              state: Notifications.dnd ? "Silenced" : "Off", on: Notifications.dnd,
              act: () => Notifications.toggleDnd() },
            { glyph: Sh.icEye, label: "Stay awake",
              state: DeckUi.stayAwake ? "On" : "Off", on: DeckUi.stayAwake,
              act: () => DeckUi.stayAwake = !DeckUi.stayAwake },
            { glyph: Sh.icCamera, label: "Screenshot", state: "Region", on: false,
              act: () => Capture.shot("region") },
            { glyph: Sh.icRecord, label: "Record",
              state: Capture.recording ? "Recording" : "Screen", on: Capture.recording, tint: DeckUi.danger,
              act: () => { if (!Capture.recording) Sh.closeDeck(); Capture.recToggle() } }
        ]
        property int cur: 0

        Connections {
            target: DeckUi
            function onNav(key) {
                if (DeckUi.zone !== "quick") return
                if (key === Qt.Key_Left)  { if (quick.cur % 2 === 0) DeckUi.go("left"); else quick.cur-- }
                if (key === Qt.Key_Right && quick.cur % 2 === 0) quick.cur++
                if (key === Qt.Key_Up && quick.cur >= 2) quick.cur -= 2
                if (key === Qt.Key_Down)  { if (quick.cur >= 2) DeckUi.go("down"); else quick.cur += 2 }
                if (key === Qt.Key_Return || key === Qt.Key_Enter) quick.items[quick.cur].act()
            }
        }

        Caption {
            id: quickCap
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
            text: "Quick"
        }

        Grid {
            anchors { left: parent.left; right: parent.right; top: quickCap.bottom; bottom: parent.bottom }
            anchors.margins: DeckUi.f(16)
            anchors.topMargin: DeckUi.f(12)
            columns: 2
            spacing: DeckUi.f(10)

            Repeater {
                model: quick.items
                Rectangle {
                    id: qt
                    required property var modelData
                    required property int index
                    readonly property bool sel: quick.focused && quick.cur === index
                    // On is neutral (a Mist chip); only Record goes coral.
                    readonly property color tint: modelData.tint || DeckUi.mist
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: DeckUi.innerRadius
                    color: modelData.on ? DeckUi.sel
                         : qt.sel ? DeckUi.sel : qtMa.containsMouse ? DeckUi.hover : DeckUi.well
                    border.width: 1
                    border.color: qt.sel ? DeckUi.selRim : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    // Icon chip: filled while the toggle is on.
                    Rectangle {
                        id: chip
                        anchors { left: parent.left; top: parent.top; margins: DeckUi.f(10) }
                        width: DeckUi.f(28); height: width
                        radius: width / 2
                        color: qt.modelData.on ? qt.tint : DeckUi.graphite
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            anchors.centerIn: parent
                            text: qt.modelData.glyph
                            color: qt.modelData.on ? (qt.modelData.tint ? DeckUi.canvas : DeckUi.iron) : DeckUi.text
                            font.family: Sh.iconFont
                            font.pixelSize: DeckUi.f(14)
                        }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(10) }
                        anchors.leftMargin: DeckUi.f(12)
                        spacing: 1
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: qt.modelData.label
                            color: DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(12)
                            font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: qt.modelData.state
                            color: qt.modelData.on ? DeckUi.text : DeckUi.dim
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(10.5)
                        }
                    }
                    MouseArea {
                        id: qtMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { quick.cur = qt.index; qt.modelData.act() }
                    }
                }
            }
        }
    }

    // ── mixer ───────────────────────────────────────────────────────────
    Card {
        id: sound
        width: col.width
        height: col.height - col.quickH - col.spacing
        focused: DeckUi.zone === "mixer"

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var source: Pipewire.defaultAudioSource
        // App playback streams (Quickshell counts them as sinks); audio binds once tracked.
        readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)
        PwObjectTracker { objects: [sound.source].concat(sound.streams).filter(o => o) }

        function _name(n) {
            const p = n.properties || {}
            const s = p["application.name"] || n.nickname || n.description || n.name || "App"
            return s.charAt(0).toUpperCase() + s.slice(1)
        }

        // Rows in keyboard order; each knows how to read, set and mute itself.
        readonly property var rows: {
            const r = [{
                key: "out", label: "Output",
                glyph: Audio.muted || Audio.volume === 0 ? Sh.icVolumeMute : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh,
                value: Audio.volume, muted: Audio.muted,
                set: v => Audio.setVolume(v), mute: () => Audio.toggleMute()
            }]
            if (sound.source && sound.source.audio) r.push({
                key: "mic", label: "Microphone",
                glyph: sound.source.audio.muted ? Sh.icMicOff : Sh.icMic,
                value: sound.source.audio.volume, muted: sound.source.audio.muted,
                set: v => sound.source.audio.volume = v, mute: () => sound.source.audio.muted = !sound.source.audio.muted
            })
            if (Brightness.available) r.push({
                key: "bri", label: "Brightness", glyph: Sh.icSun,
                value: sound._briWant >= 0 ? sound._briWant : Brightness.pct, muted: false,
                set: v => { sound._briWant = v; if (!briThrottle.running) briThrottle.start() }, mute: () => {}
            })
            for (const n of sound.streams.filter(s => s.audio)) r.push({
                key: "app:" + n.id, label: sound._name(n), glyph: Sh.icMusic,
                value: n.audio.volume, muted: n.audio.muted,
                set: v => n.audio.volume = v, mute: () => n.audio.muted = !n.audio.muted
            })
            return r
        }
        property int cur: 0
        onRowsChanged: cur = Math.min(cur, rows.length - 1)

        // Brightness shells out per change; coalesce drags.
        property real _briWant: -1
        Timer {
            id: briThrottle
            interval: 60
            onTriggered: if (sound._briWant >= 0) { Brightness.set(sound._briWant); sound._briWant = -1 }
        }

        Connections {
            target: DeckUi
            function onNav(key) {
                if (DeckUi.zone !== "mixer" || sound.rows.length === 0) return
                const r = sound.rows[sound.cur]
                if (key === Qt.Key_Up)    { if (sound.cur === 0) DeckUi.go("up"); else sound.cur-- }
                if (key === Qt.Key_Down)  sound.cur = Math.min(sound.rows.length - 1, sound.cur + 1)
                if (key === Qt.Key_Left)  r.set(Math.max(0, r.value - 0.05))
                if (key === Qt.Key_Right) r.set(Math.min(1, r.value + 0.05))
                if (key === Qt.Key_Return || key === Qt.Key_Enter) r.mute()
            }
        }

        Caption {
            id: soundCap
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
            text: "Mixer"
            readonly property int apps: sound.streams.filter(s => s.audio).length
            trailing: apps + (apps === 1 ? " app" : " apps")
        }

        Flickable {
            anchors { left: parent.left; right: parent.right; top: soundCap.bottom; bottom: parent.bottom }
            // Inset by the row highlight's overhang so clipping doesn't cut it.
            anchors.margins: DeckUi.f(10)
            anchors.topMargin: DeckUi.f(10)
            contentHeight: mix.height + DeckUi.f(12)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: mix
                x: DeckUi.f(6)
                y: DeckUi.f(6)
                width: parent.width - DeckUi.f(12)
                spacing: DeckUi.f(14)

                Repeater {
                    model: sound.rows
                    Slider {
                        required property var modelData
                        required property int index
                        width: mix.width
                        label: modelData.label
                        glyph: modelData.glyph
                        value: modelData.value
                        muted: modelData.muted
                        selected: sound.focused && sound.cur === index
                        onMoved: (v) => modelData.set(v)
                        onGlyphClicked: modelData.mute()
                    }
                }
            }
        }
    }

}
