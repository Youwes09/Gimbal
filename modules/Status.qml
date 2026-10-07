pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "root:/modules"

// Glanceable state shared by the launcher header and the rest screen.
QtObject {
    id: root

    // Only tick while something showing it is up.
    readonly property bool _watched: Sh.launcherShown || Sh.shown
    property date now: new Date()
    property Timer _tick: Timer {
        running: root._watched
        repeat: true
        triggeredOnStart: true
        // Fire just after each minute boundary so the clock flips on time.
        interval: 60000 - (Date.now() % 60000) + 50
        onTriggered: {
            root.now = new Date()
            interval = 60000 - (Date.now() % 60000) + 50
        }
    }

    readonly property var _days:   ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var _months: ["January", "February", "March", "April", "May", "June",
                                    "July", "August", "September", "October", "November", "December"]

    readonly property string time: {
        const h = root.now.getHours() % 12 || 12
        const m = root.now.getMinutes()
        return h + ":" + (m < 10 ? "0" : "") + m
    }
    readonly property string meridiem: root.now.getHours() < 12 ? "AM" : "PM"
    readonly property string day:  root._days[root.now.getDay()]
    readonly property string date: root._months[root.now.getMonth()] + " " + root.now.getDate()

    readonly property var _bat: UPower.displayDevice
    readonly property bool hasBattery: root._bat && root._bat.isLaptopBattery
    readonly property int  pct: root.hasBattery ? Math.round(root._bat.percentage * 100) : 0
    readonly property bool charging: root.hasBattery
        && (root._bat.state === UPowerDeviceState.Charging
            || root._bat.state === UPowerDeviceState.FullyCharged)
    readonly property bool low: root.hasBattery && !root.charging && root.pct <= 20

    function _dur(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    readonly property string batteryNote: {
        if (!root.hasBattery) return ""
        if (root._bat.state === UPowerDeviceState.FullyCharged || root.pct >= 100) return "full"
        if (root.charging) {
            const t = root._dur(root._bat.timeToFull)
            return t ? t + " to full" : "charging"
        }
        const t = root._dur(root._bat.timeToEmpty)
        return t ? t + " left" : ""
    }

    readonly property var player: {
        const ps = Mpris.players.values
        let best = null
        for (const p of ps) {
            if (!p.trackTitle) continue
            if (p.playbackState === MprisPlaybackState.Playing) return p
            if (!best) best = p
        }
        return best
    }
    readonly property bool playing: root.player !== null
        && root.player.playbackState === MprisPlaybackState.Playing
    readonly property string track: root.player
        ? root.player.trackTitle + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "")
        : ""
}
