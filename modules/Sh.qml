pragma Singleton

import QtQuick
import Quickshell
import "root:/modules"

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
    readonly property string icSpaces:        "\ue0ff"
    readonly property string icSave:          "\ue14d"
    readonly property string icRestore:       "\ue1f5"
    readonly property string icWallpaper:     "\ue44b"
    readonly property string icTrash:         "\ue18d"
    readonly property string icPencil:        "\ue1f9"
    readonly property string icEmpty:         "\ue1cb"
    readonly property string icWifi:          "\ue1ae"
    readonly property string icWifiHigh:      "\ue5f7"
    readonly property string icWifiLow:       "\ue5f8"
    readonly property string icWifiZero:      "\ue5f9"
    readonly property string icWifiOff:       "\ue1af"
    readonly property string icBluetooth:     "\ue05c"
    readonly property string icBluetoothOn:   "\ue1b8"
    readonly property string icBluetoothOff:  "\ue1b9"
    readonly property string icRadar:         "\ue497"
    readonly property string icRadio:         "\ue142"
    readonly property string icRadioOff:      "\ue6dd"
    readonly property string icArrowIn:       "\ue043"
    readonly property string icArrowOut:      "\ue04d"
    readonly property string icHeadphones:    "\ue0f1"
    readonly property string icMouse:         "\ue28e"
    readonly property string icGamepad:       "\ue0df"
    readonly property string icPhone:         "\ue163"
    readonly property string icSpeaker:       "\ue166"
    readonly property string icWatch:         "\ue1ad"
    readonly property string icLaptop:        "\ue1cd"
    readonly property string icNetwork:       "\ue125"
    readonly property string icGlobe:         "\ue0e8"
    readonly property string icCalendar:      "\ue063"
    readonly property string icTimer:         "\ue1e0"
    readonly property string icFolderOpen:    "\ue247"
    readonly property string icRotate:        "\ue149"
    readonly property string icLogOut:        "\ue10e"
    readonly property string icCommand:       "\ue09a"
    readonly property string icGitBranch:     "\ue0e2"
    readonly property string icGitCommit:     "\ue0e3"
    readonly property string icGitPull:       "\ue0e5"
    readonly property string icGitMerge:      "\ue0e4"
    readonly property string icGitFork:       "\ue28d"
    readonly property string icStar:          "\ue176"
    readonly property string icTag:           "\ue17f"
    readonly property string icMessage:       "\ue117"
    readonly property string icExternal:      "\ue0b9"

    function batteryGlyph(pct, charging) {
        if (charging)  return root.icBatteryChg
        if (pct <= 15) return root.icBatteryLow
        if (pct <= 55) return root.icBatteryMed
        return root.icBatteryFull
    }

    property real fontScale: 1.06
    function fs(px) { return Theme.s(px * root.fontScale) }
    // A size on one surface: its built-in scale, then its own from Config.scales.
    readonly property var _partScale: ({ bar: 1.1 })
    function sz(part, px) {
        return Theme.s(px * root.fontScale * (root._partScale[part] || 1) * Config.scaleOf(part))
    }

    // The focused output, from mango. Summoned surfaces open on it and stay there while open.
    readonly property var focusedScreen:
        Quickshell.screens.find(s => s.name === Spaces.monitor) || Quickshell.screens[0] || null
    property var screen: null

    // Only one summoned surface at a time.
    function _closeAll() {
        root.launcherShown = false; root.deckShown = false; root.shown = false
        root.screen = root.focusedScreen
    }

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
    property string launcherSeed: ""     // text the next launcher open starts with
    property string launcherMode: ""     // the open launcher's mode, set by its page
    readonly property var _modePrefix: ({ run: ">", calc: "=", clipboard: ";", emoji: ":", files: "/" })
    // Opens the launcher in one mode; closes it if it's already there.
    function toggleLauncherMode(m) {
        const p = root._modePrefix[m]
        if (!p) return
        if (root.launcherShown && root.launcherMode === m) { root.closeLauncher(); return }
        root.launcherSeed = p
        if (!root.launcherShown) root.openLauncher()
    }
    function closeLauncher()  { root.launcherShown = false }

    // The deck (Super+Tab).
    property bool deckShown: false
    function toggleDeck() { if (root.deckShown) root.closeDeck(); else root.openDeck() }
    function openDeck()   { root._closeAll(); root.deckShown = true }
    function closeDeck()  { root.deckShown = false }

    // The bar's edge, or "" when off or hidden.
    property bool barHidden: false
    readonly property string barEdge: root.barHidden ? "" : Config.bar
    readonly property int barHeight: root.sz("bar", 32)
    readonly property int barMargin: root.sz("bar", 8)
    readonly property int barTop: root.barEdge === "top" ? root.barHeight + root.barMargin : 0

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
