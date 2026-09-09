pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string location: Quickshell.env("GIMBAL_WEATHER_LOCATION") || ""

    property string text: ""
    property bool   ok:   false
    property bool   failed: false

    property string condition: ""
    property int    tempC: 0
    property int    hiC: 0
    property int    loC: 0
    property int    humidity: 0

    property Process _fetch: Process {
        command: ["bash", "-c",
            "export PATH=\"$PATH:/usr/bin:/usr/local/bin:/bin\"; curl -fs -m 8 \"wttr.in/$1?format=j1\"",
            "_", root.location]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                root.failed = raw.length === 0
                if (root.failed) return
                try {
                    const j = JSON.parse(raw)
                    const cur = j.current_condition[0]
                    const day = j.weather[0]
                    root.condition = (cur.weatherDesc[0].value || "").trim()
                    root.tempC     = Math.round(Number(cur.temp_C))
                    root.humidity  = Math.round(Number(cur.humidity))
                    root.hiC       = Math.round(Number(day.maxtempC))
                    root.loC       = Math.round(Number(day.mintempC))
                    root.text      = root.condition + " " + root.tempC + "°"
                    root.ok        = true
                } catch (e) {
                    root.failed = true
                    root.ok = false
                }
            }
        }
    }

    function refetch() {
        _fetch.running = false
        _fetch.running = true
    }

    property Timer _refresh: Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refetch()
    }

    property Timer _retry: Timer {
        property int attempt: 0
        interval: Math.min(15 * 60 * 1000, 5000 * Math.pow(2, attempt))
        running: root.failed
        repeat: true
        onTriggered: { attempt++; root.refetch() }
        onRunningChanged: if (!running) attempt = 0
    }

    function glyphFor(condition) {
        const t = (condition || "").toLowerCase()
        if (t.includes("thunder")) return Sh.icCloudStorm
        if (t.includes("snow") || t.includes("sleet") || t.includes("ice")) return Sh.icSnow
        if (t.includes("rain") || t.includes("drizzle") || t.includes("shower")) return Sh.icCloudRain
        if (t.includes("fog") || t.includes("mist") || t.includes("haze")
            || t.includes("overcast") || t.includes("cloud")) return Sh.icCloud
        if (t.includes("clear") || t.includes("sunny")) return Sh.icSun
        return ""
    }
}
