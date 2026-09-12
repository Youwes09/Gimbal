pragma Singleton

import QtQuick

QtObject {
    id: root

    property string kind: ""

    function pulse(k) {
        root.kind = k
        hide.restart()
    }

    property Timer hide: Timer {
        interval: 1400
        onTriggered: root.kind = ""
    }
}
