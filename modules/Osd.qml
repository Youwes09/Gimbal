pragma Singleton

import QtQuick
import "root:/modules"

QtObject {
    id: root

    property string kind: ""

    function pulse(k) {
        // The deck has its own sliders; no popup on top of them.
        if (Sh.deckShown) return
        root.kind = k
        hide.restart()
    }

    property Timer hide: Timer {
        interval: 1400
        onTriggered: root.kind = ""
    }
}
