pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "root:/modules"

// Idle → rest screen, longer idle → black. Apps holding an idle inhibitor (video, calls) keep it away,
// and so does media playing outside a music player; pausing starts the count again.
QtObject {
    id: root

    readonly property bool dark: _darkMon.isIdle

    readonly property bool watching: Mpris.players.values.some(p =>
        p.playbackState === MprisPlaybackState.Playing
        && !Config.idleMusicPlayers.includes(String(p.desktopEntry || "").toLowerCase())
        && !Config.idleMusicPlayers.includes(String(p.identity || "").toLowerCase()))

    property IdleMonitor _restMon: IdleMonitor {
        enabled: Config.idleRest > 0 && !root.watching
        timeout: Config.idleRest
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !(Sh.shown && Sh.page === "rest")) Sh.rest()
    }

    property IdleMonitor _darkMon: IdleMonitor {
        enabled: Config.idleDark > 0 && !root.watching
        timeout: Config.idleDark
        respectInhibitors: true
    }
}
