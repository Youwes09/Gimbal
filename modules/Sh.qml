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
    readonly property string icBolt:       "\ue1b4"
    readonly property string icBatteryLow:  "\ue056"
    readonly property string icBatteryMed:  "\ue057"
    readonly property string icBatteryFull: "\ue055"
    readonly property string icBatteryChg:  "\ue054"
    readonly property string icChevronsDown: "\ue071"
    readonly property string icPower:        "\ue140"
    readonly property string icMoon:         "\ue11e"
    readonly property string icSearch:       "\ue151"
    readonly property string icCorner:       "\ue0a1"
    readonly property string icFile:         "\ue0c0"
    readonly property string icFolder:       "\ue0d7"
    readonly property string icApp:          "\ue426"
    readonly property string icTerm:         "\ue181"
    readonly property string icMic:           "\ue118"
    readonly property string icMicOff:        "\ue119"
    readonly property string icMonitor:       "\ue11d"
    readonly property string icRefresh:       "\ue145"
    readonly property string icMusic:         "\ue122"
    readonly property string icSkipBack:      "\ue15f"
    readonly property string icSkipForward:   "\ue160"
    readonly property string icPlay:          "\ue13c"
    readonly property string icPause:         "\ue12e"
    readonly property string icDroplet:       "\ue0b4"
    readonly property string icLock:          "\ue10b"
    readonly property string icBell:          "\ue059"
    readonly property string icBellOff:       "\ue05a"
    readonly property string icX:             "\ue1b2"
    readonly property string icVolumeLow:     "\ue1aa"
    readonly property string icVolumeHigh:    "\ue1ab"
    readonly property string icVolumeMute:    "\ue1ac"
    readonly property string icHome:          "\ue0f5"
    readonly property string icImages:        "\ue5c4"
    readonly property string icCpu:           "\ue0a9"
    readonly property string icRam:           "\ue445"
    readonly property string icGauge:         "\ue1bf"
    readonly property string icThermo:        "\ue186"
    readonly property string icFolderGit:     "\ue40a"
    readonly property string icCamera:        "\ue064"
    readonly property string icRecord:        "\ue345"
    readonly property string icKeyboard:      "\ue284"
    readonly property string icKeyboardOff:   "\ue5de"
    readonly property string icWallpaper:     "\ue44b"
    readonly property string icTrash:         "\ue18d"
    readonly property string icFolderOpen:    "\ue247"
    readonly property string icRotate:        "\ue149"
    readonly property string icLogOut:        "\ue10e"

    function batteryGlyph(pct, charging) {
        if (charging)  return root.icBatteryChg
        if (pct <= 15) return root.icBatteryLow
        if (pct <= 55) return root.icBatteryMed
        return root.icBatteryFull
    }

    property real fontScale: 1.06
    function fs(px) { return Math.round(px * root.fontScale) }

    // Only one summoned surface at a time.
    function _closeAll() { root.launcherShown = false; root.deckShown = false; root.shown = false }

    // The overlay window: the "wallpaper" carousel or the "rest" screen (idle / Super+L).
    property bool   shown: false
    property string page:  "wallpaper"
    function walls()  { root._closeAll(); root.page = "wallpaper"; root.shown = true }
    function toggleWalls() { if (root.shown && root.page === "wallpaper") root.close(); else root.walls() }
    function rest()   { root._closeAll(); root.page = "rest"; root.shown = true }
    function close()  { root.shown = false }

    // The launcher (Super+Shift+A).
    property bool launcherShown: false
    function toggleLauncher() { if (root.launcherShown) root.closeLauncher(); else root.openLauncher() }
    function openLauncher()   { root._closeAll(); root.launcherShown = true }
    function closeLauncher()  { root.launcherShown = false }

    // The deck (Super+Tab).
    property bool deckShown: false
    function toggleDeck() { if (root.deckShown) root.closeDeck(); else root.openDeck() }
    function openDeck()   { root._closeAll(); root.deckShown = true }
    function closeDeck()  { root.deckShown = false }

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
