pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Power draw, read from sysfs every two seconds. On battery it's the whole laptop
// (battery current × voltage); on AC the battery reads zero, so it falls back to the
// processor package (amdgpu's PPT sensor, which covers CPU and iGPU on an APU).
QtObject {
    id: root

    readonly property int interval: 2000
    readonly property int keep: 90                   // three minutes of samples
    property var hist: []
    readonly property real watts: root.hist.length ? root.hist[root.hist.length - 1] : 0
    property bool onBattery: false
    readonly property string source: root.onBattery ? "Draw" : "Package"
    readonly property bool available: root.hist.length > 0

    // Normal is the median of the last few minutes; a peak is well clear of it.
    readonly property real normal: {
        if (root.hist.length < 10) return 0
        const s = root.hist.slice().sort((a, b) => a - b)
        return s[Math.floor(s.length / 2)]
    }
    readonly property bool peaking: root.normal > 0 && root.watts > Math.max(root.normal * 1.5, root.normal + 3)

    property string _ppt: ""                         // amdgpu hwmon power file, found once
    property Process _find: Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name)\" = amdgpu ] && [ -r $h/power1_average ] && echo $h/power1_average && break; done"]
        stdout: StdioCollector { onStreamFinished: root._ppt = this.text.trim() }
    }

    readonly property string _bat: "/sys/class/power_supply/BAT1/"
    property FileView _status: FileView { path: root._bat + "status"; blockLoading: true }
    property FileView _current: FileView { path: root._bat + "current_now"; blockLoading: true }
    property FileView _voltage: FileView { path: root._bat + "voltage_now"; blockLoading: true }
    property FileView _pkg: FileView { path: root._ppt; blockLoading: true }

    property Timer _tick: Timer {
        running: true
        repeat: true
        interval: root.interval
        onTriggered: {
            root._status.reload(); root._current.reload(); root._voltage.reload()
            const discharging = root._status.text().trim() === "Discharging"
            let w = 0
            if (discharging) {
                w = (parseInt(root._current.text()) || 0) * (parseInt(root._voltage.text()) || 0) / 1e12
            }
            if (!discharging || w <= 0) {
                if (!root._ppt) return
                root._pkg.reload()
                w = (parseInt(root._pkg.text()) || 0) / 1e6
            }
            root.onBattery = discharging
            const h = root.hist.concat([w])
            root.hist = h.length > root.keep ? h.slice(-root.keep) : h
        }
    }
    // A switch between battery and package readings isn't one series.
    onOnBatteryChanged: root.hist = []
}
