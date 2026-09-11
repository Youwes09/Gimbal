pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: root

    property string phase: ""
    property bool slow: false
    property string title: ""
    property string icon: ""
    property var names: []

    function begin(title, icon, names) {
        root.title = title || "App"
        root.icon = icon || ""
        root.names = names || []
        root.phase = "starting"
        root.slow = false
        watch.restart()
        slowMark.restart()
        giveUp.restart()
        hide.stop()
    }

    function _found() {
        watch.stop(); slowMark.stop(); giveUp.stop()
        root.phase = "ok"
        hide.restart()
    }

    property Timer watch: Timer {
        interval: 200; repeat: true
        onTriggered: {
            if (root.phase !== "starting") { watch.stop(); return }
            if (Compositor.find(root.names) || Compositor.findTray(root.names))
                root._found()
        }
    }
    property Timer slowMark: Timer {
        interval: 8000
        onTriggered: if (root.phase === "starting") root.slow = true
    }
    property Timer giveUp: Timer {
        interval: 45000
        onTriggered: { watch.stop(); slowMark.stop(); root.phase = ""; root.slow = false }
    }
    property Timer hide: Timer {
        interval: 1600
        onTriggered: { root.phase = ""; root.slow = false }
    }
}
