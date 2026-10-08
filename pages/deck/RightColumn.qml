import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "root:/modules"

// Controls: quick toggles, then sound (output, mic, each app playing) and display brightness.
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
            // Enter cycles Quiet → Balanced → Performance; lit whenever it's off the default.
            { glyph: Machine.profile === "Performance" ? Sh.icBolt
                   : Machine.profile === "Quiet" ? Sh.icChevronsDown : Sh.icGauge,
              label: "Power", state: Machine.hasProfile ? Machine.profile : "Unavailable",
              on: Machine.hasProfile && Machine.profile !== "Balanced",
              act: () => Machine.nextProfile() },
            { glyph: Sh.icMoon, label: "Warm light",
              state: !Machine.hasWarmth ? "Unavailable"
                   : Machine.warmth ? (Machine.kelvin > 0 ? Machine.kelvin + "K" : "On") : "Off",
              on: Machine.warmth, act: () => Machine.toggleWarmth() }
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
                    // On fills the chip with the accent; Record uses coral.
                    readonly property color tint: modelData.tint || DeckUi.accent
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
                            color: qt.modelData.on ? (qt.modelData.tint ? "#ffffff" : DeckUi.accentInk) : DeckUi.text
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
                            font.weight: Font.DemiBold
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

    // ── sound + display ─────────────────────────────────────────────────
    // Sound: the output, the microphone, then one row per app playing (with its own icon).
    // Display: brightness, pinned to the bottom. One keyboard list runs through both.
    Card {
        id: sound
        width: col.width
        height: col.height - col.quickH - col.spacing
        focused: DeckUi.zone === "mixer"

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var source: Pipewire.defaultAudioSource
        // App playback streams (Quickshell counts them as sinks); audio binds once tracked.
        readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
        PwObjectTracker { objects: [sound.sink, sound.source].concat(sound.streams).filter(o => o) }

        function _appName(n) {
            const p = n.properties || {}
            const s = p["application.name"] || n.nickname || n.description || n.name || "App"
            return s.charAt(0).toUpperCase() + s.slice(1)
        }
        function _appIcon(n) {
            const p = n.properties || {}
            for (const k of [p["application.icon_name"], p["application.process.binary"],
                             String(p["application.name"] || "").toLowerCase()]) {
                const i = k ? Quickshell.iconPath(k, true) : ""
                if (i) return i
            }
            return ""
        }
        // Built-in devices have unhelpful names ("ALC285 Analog"); anything plugged in or
        // paired (headphones, a USB interface) keeps its own.
        function _device(n, builtin) {
            if (!n) return builtin
            const name = String(n.name || "")
            return name.indexOf(".pci-") >= 0 ? builtin : (n.description || n.nickname || builtin)
        }

        // Rows in keyboard order; each knows how to read, set and mute itself.
        readonly property var soundRows: {
            const r = [{
                key: "out", label: sound._device(sound.sink, "Speakers"),
                glyph: Audio.muted || Audio.volume === 0 ? Sh.icVolumeMute : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh,
                value: Audio.volume, muted: Audio.muted,
                set: v => Audio.setVolume(v), mute: () => Audio.toggleMute()
            }]
            if (sound.source && sound.source.audio) r.push({
                key: "mic", label: sound._device(sound.source, "Microphone"),
                glyph: sound.source.audio.muted ? Sh.icMicOff : Sh.icMic,
                value: sound.source.audio.volume, muted: sound.source.audio.muted,
                set: v => sound.source.audio.volume = v, mute: () => sound.source.audio.muted = !sound.source.audio.muted
            })
            for (const n of sound.streams) r.push({
                key: "app:" + n.id, label: sound._appName(n), glyph: Sh.icMusic, icon: sound._appIcon(n),
                value: n.audio.volume, muted: n.audio.muted,
                set: v => n.audio.volume = v, mute: () => n.audio.muted = !n.audio.muted
            })
            return r
        }
        readonly property var briRow: Brightness.available ? {
            key: "bri", label: "Brightness", glyph: Sh.icSun, mutable: false,
            value: sound._briWant >= 0 ? sound._briWant : Brightness.pct, muted: false,
            set: v => { sound._briWant = v; if (!briThrottle.running) briThrottle.start() }, mute: () => {}
        } : null
        readonly property var rows: sound.briRow ? sound.soundRows.concat([sound.briRow]) : sound.soundRows
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

        component Row_: Slider {
            required property var modelData
            required property int index
            label: modelData.label
            glyph: modelData.glyph
            icon: modelData.icon || ""
            mutable: modelData.mutable !== false
            value: modelData.value
            muted: modelData.muted
            selected: sound.focused && sound.cur === index
            onMoved: (v) => modelData.set(v)
            onGlyphClicked: modelData.mute()
        }

        Caption {
            id: soundCap
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: DeckUi.f(16) }
            text: "Sound"
        }

        Flickable {
            anchors { left: parent.left; right: parent.right; top: soundCap.bottom; bottom: displayCap.top }
            // Inset by the row highlight's overhang so clipping doesn't cut it.
            anchors.leftMargin: DeckUi.f(10)
            anchors.rightMargin: DeckUi.f(10)
            anchors.topMargin: DeckUi.f(6)
            anchors.bottomMargin: DeckUi.f(10)
            contentHeight: mix.height + DeckUi.f(12)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: mix
                x: DeckUi.f(6)
                y: DeckUi.f(6)
                width: parent.width - DeckUi.f(12)
                spacing: DeckUi.f(10)

                Repeater {
                    model: sound.soundRows
                    Row_ { width: mix.width }
                }
            }
        }

        Caption {
            id: displayCap
            visible: sound.briRow !== null
            anchors { left: parent.left; right: parent.right; bottom: briSlot.top; margins: DeckUi.f(16) }
            anchors.bottomMargin: DeckUi.f(10)
            text: "Display"
        }
        Item {
            id: briSlot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(16) }
            height: sound.briRow ? DeckUi.f(48) : 0
            Loader {
                anchors.fill: parent
                active: sound.briRow !== null
                sourceComponent: Row_ {
                    modelData: sound.briRow
                    index: sound.rows.length - 1
                }
            }
        }
    }
}
