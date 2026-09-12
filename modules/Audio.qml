pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "root:/modules"

QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    property PwObjectTracker _t: PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0
    readonly property bool muted: (root.sink && root.sink.audio) ? root.sink.audio.muted : false

    function setVolume(v) {
        if (!root.sink || !root.sink.audio) return
        root.sink.audio.volume = Math.max(0, Math.min(1.5, v))
        if (root.sink.audio.volume > 0 && root.sink.audio.muted) root.sink.audio.muted = false
        Osd.pulse("volume")
    }
    function nudge(delta) { root.setVolume(root.volume + delta) }
    function toggleMute() {
        if (!root.sink || !root.sink.audio) return
        root.sink.audio.muted = !root.sink.audio.muted
        Osd.pulse("volume")
    }
}
