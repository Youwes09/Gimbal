import QtQuick
import Quickshell.Services.Pipewire
import "root:/modules"

// Controls: a mixer (output, mic, brightness, each app playing) and quick toggles.
Column {
    id: col
    spacing: DeckUi.f(12)

    readonly property real quickH: DeckUi.f(188)

    // ── sound ───────────────────────────────────────────────────────────
    Card {
        id: sound
        width: col.width
        height: col.height - col.quickH - col.spacing
        focused: DeckUi.zone === "sound"

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
                if (DeckUi.zone !== "sound" || sound.rows.length === 0) return
                const r = sound.rows[sound.cur]
                if (key === Qt.Key_Up)    sound.cur = Math.max(0, sound.cur - 1)
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
            anchors.margins: DeckUi.f(16)
            anchors.topMargin: DeckUi.f(16)
            contentHeight: mix.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: mix
                width: parent.width
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
              state: Capture.recording ? "Recording" : "Screen", on: Capture.recording, tint: Theme.error,
              act: () => { if (!Capture.recording) Sh.closeDeck(); Capture.recToggle() } }
        ]
        property int cur: 0

        Connections {
            target: DeckUi
            function onNav(key) {
                if (DeckUi.zone !== "quick") return
                if (key === Qt.Key_Left)  quick.cur = quick.cur % 2 === 1 ? quick.cur - 1 : quick.cur
                if (key === Qt.Key_Right) quick.cur = quick.cur % 2 === 0 ? quick.cur + 1 : quick.cur
                if (key === Qt.Key_Up)    quick.cur = quick.cur >= 2 ? quick.cur - 2 : quick.cur
                if (key === Qt.Key_Down)  quick.cur = quick.cur < 2 ? quick.cur + 2 : quick.cur
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
                    readonly property color tint: modelData.tint || Theme.accent
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: DeckUi.innerRadius
                    color: modelData.on ? Qt.alpha(qt.tint, 0.15)
                         : qt.sel ? DeckUi.sel : qtMa.containsMouse ? DeckUi.hover : DeckUi.well
                    border.width: 1
                    border.color: qt.sel ? DeckUi.selRim : modelData.on ? Qt.alpha(qt.tint, 0.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: DeckUi.f(12) }
                        text: qt.modelData.glyph
                        color: qt.modelData.on ? qt.tint : Theme.fg
                        font.family: Sh.iconFont
                        font.pixelSize: DeckUi.f(17)
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: DeckUi.f(40)
                        anchors.rightMargin: DeckUi.f(8)
                        spacing: 1
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: qt.modelData.label
                            color: Theme.fg
                            font.family: Sh.font
                            font.pixelSize: DeckUi.f(12)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: qt.modelData.state
                            color: qt.modelData.on ? qt.tint : DeckUi.dim
                            font.family: Sh.font
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
}
