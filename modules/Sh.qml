pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: root

    property FontLoader _monoRegular: FontLoader {
        source: "root:/assets/fonts/AdwaitaMono-Regular.ttf"
    }
    property FontLoader _monoBold: FontLoader {
        source: "root:/assets/fonts/AdwaitaMono-Bold.ttf"
    }
    readonly property string font: _monoRegular.status === FontLoader.Ready
        ? _monoRegular.name
        : (Quickshell.env("QS_FONT_FAMILY") || "monospace")

    property FontLoader _iconFont: FontLoader {
        source: "root:/assets/fonts/lucide.ttf"
    }
    readonly property string iconFont: _iconFont.name

    readonly property string icSun:        "\ue178"
    readonly property string icCloud:      "\ue088"
    readonly property string icCloudRain:  "\ue08e"
    readonly property string icCloudStorm: "\ue08c"
    readonly property string icSnow:       "\ue090"
    readonly property string icBolt:       "\ue1b4"
    readonly property string icBattery:     "\ue053"
    readonly property string icBatteryLow:  "\ue056"
    readonly property string icBatteryMed:  "\ue057"
    readonly property string icBatteryFull: "\ue055"
    readonly property string icBatteryChg:  "\ue054"
    readonly property string icChevronsUp:   "\ue074"
    readonly property string icChevronsDown: "\ue071"
    readonly property string icPower:        "\ue140"
    readonly property string icMoon:         "\ue11e"
    readonly property string icSearch:       "\ue151"
    readonly property string icCorner:       "\ue0a1"
    readonly property string icFile:         "\ue0c0"
    readonly property string icFolder:       "\ue0d7"
    readonly property string icApp:          "\ue426"
    readonly property string icTerm:         "\ue181"
    readonly property string icWifi:          "\ue1ae"
    readonly property string icWifiOff:       "\ue1af"
    readonly property string icBluetooth:     "\ue05c"
    readonly property string icBluetoothOff:  "\ue1b9"
    readonly property string icMic:           "\ue118"
    readonly property string icMicOff:        "\ue119"
    readonly property string icCoffee:        "\ue096"
    readonly property string icMonitor:       "\ue11d"
    readonly property string icRefresh:       "\ue145"
    readonly property string icMusic:         "\ue122"
    readonly property string icSkipBack:      "\ue15f"
    readonly property string icSkipForward:   "\ue160"
    readonly property string icPlay:          "\ue13c"
    readonly property string icPause:         "\ue12e"
    readonly property string icDroplet:       "\ue0b4"
    readonly property string icTheme:         "\ue2b2"
    readonly property string icClock:         "\ue087"
    readonly property string icLock:          "\ue10b"
    readonly property string icHardDrive:     "\ue0ed"
    readonly property string icMemory:        "\ue445"

    function batteryGlyph(pct, charging) {
        if (charging)  return root.icBatteryChg
        if (pct <= 15) return root.icBatteryLow
        if (pct <= 55) return root.icBatteryMed
        return root.icBatteryFull
    }

    property real fontScale: 1.06
    function fs(px) { return Math.round(px * root.fontScale) }

    property bool   shown: false
    property string page:  "clock"

    property string powerZone: ""
    property real   powerPush: 0
    property real   powerDim: 0

    function toggle(p) {
        if (root.shown) root.close()
        else            root.open(p)
    }
    function open(p) {
        if (p && p.length > 0) root.page = p
        root.shown = true
    }
    function close() {
        root.shown = false
    }

    property bool launcherShown: false
    function toggleLauncher() { root.launcherShown = !root.launcherShown }
    function openLauncher()   { root.launcherShown = true }
    function closeLauncher()  { root.launcherShown = false }

    property real reveal: 0

    property var originFraction: [0.0, 0.0]

    property real screenWidth:  0
    property real screenHeight: 0

    readonly property real originX: originFraction[0] * screenWidth
    readonly property real originY: originFraction[1] * screenHeight

    readonly property real maxRadius: 1.02 * Math.max(
        Math.hypot(originX,               originY),
        Math.hypot(screenWidth - originX, originY),
        Math.hypot(originX,               screenHeight - originY),
        Math.hypot(screenWidth - originX, screenHeight - originY))

    readonly property int  revealDiameter: Math.max(1, Math.ceil(2 * maxRadius * reveal))
    readonly property real revealRadius:   revealDiameter / 2

    function reached(x, y) {
        return Math.hypot(x - originX, y - originY) <= revealRadius
    }
}
