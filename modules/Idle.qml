pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules"

// Idle → rest screen, longer idle → black. Apps holding an idle inhibitor (video, calls) keep it away.
QtObject {
    id: root

    readonly property bool dark: _darkMon.isIdle

    property IdleMonitor _restMon: IdleMonitor {
        enabled: Config.idleRest > 0
        timeout: Config.idleRest
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !(Sh.shown && Sh.page === "rest")) Sh.rest()
    }

    property IdleMonitor _darkMon: IdleMonitor {
        enabled: Config.idleDark > 0
        timeout: Config.idleDark
        respectInhibitors: true
    }
}
