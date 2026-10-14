import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "root:/modules"

ShellRoot {
    id: shellRoot

    readonly property int _trayCount: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property int _batteryWatch: BatteryWatch.pct
    readonly property bool _idle: Idle.dark
    readonly property int _spaces: Spaces.active
    readonly property bool _net: Net.live
    readonly property real _power: Power.watts
    readonly property int _gpus: SysStats.gpus.length
    readonly property bool _kbd: Kbd.available

    WallpaperWindow { }
    Bar { }
    Overlay { id: overlay }
    LauncherWindow { id: launcher }
    DeckWindow { }
    NotificationToasts { }
    LaunchIndicator { }
    RecordingIndicator { }
    OsdIndicator { }
    RegionPicker { }
    PolkitPrompt { }

    IpcHandler {
        target: "deck"

        function toggle(): void { Sh.toggleDeck() }
        function open():   void { Sh.openDeck() }
        function close():  void { Sh.closeDeck() }
        // Opens the deck on a page; closes it if it's already there.
        function page(id: string): void {
            if (DeckUi.sections.indexOf(id) < 0) return
            if (Sh.deckShown && DeckUi.section === id) Sh.closeDeck()
            else if (Sh.deckShown) DeckUi.section = id
            else { DeckUi.openTo = id; Sh.openDeck() }
        }
        // Feeds one key to the open deck's navigation (left, right, up, down, enter, delete).
        function key(name: string): void {
            const k = { left: Qt.Key_Left, right: Qt.Key_Right, up: Qt.Key_Up, down: Qt.Key_Down,
                        enter: Qt.Key_Return, delete: Qt.Key_Delete }[name]
            if (Sh.deckShown && k) DeckUi.nav(k, 0)
        }
    }

    IpcHandler {
        target: "overlay"

        function walls():  void { Sh.toggleWalls() }
        function rest():   void { Sh.rest() }
        function close():  void { Sh.close() }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { Sh.toggleLauncher() }
        function open():   void { Sh.openLauncher() }
        function close():  void { Sh.closeLauncher() }
        function search(text: string): void { Sh.launcherSeed = text ?? ""; if (!Sh.launcherShown) Sh.openLauncher() }
        // run, calc, clipboard, emoji or files
        function mode(m: string): void { Sh.toggleLauncherMode(m ?? "") }
    }

    IpcHandler {
        target: "wallpaper"

        function set(name: string): void {
            const p = Wallpapers.byName(name ?? "")
            if (p.length > 0) Wallpapers.apply(p)
        }
        function next():          void { Wallpapers.next() }
        function prev():          void { Wallpapers.prev() }
        function random():        void { Wallpapers.random() }
        function rescan():        void { Wallpapers.rescan() }
        function current():     string { return Wallpapers.current }
        function list():        string { return Wallpapers.list.map(w => w.name).join("\n") }
    }

    IpcHandler {
        target: "notifications"

        function dnd():  string { Notifications.toggleDnd(); return Notifications.dnd ? "on" : "off" }
        function clear():  void { Notifications.clearAll() }
        function state(): string { return Notifications.dnd ? "dnd" : "on" }
    }

    IpcHandler {
        target: "capture"

        function screenshot(mode: string): void { Capture.shot(mode ?? "region", true) }
        function record(mode: string):     void { Capture.recStart(mode ?? "full") }
        function stop():                   void { Capture.recStop() }
        function recordToggle():           void { Capture.recToggle() }
        function recording():            string { return Capture.recording ? "on" : "off" }
    }

    IpcHandler {
        target: "spaces"

        function restore():         void { Spaces.restore(Spaces.last) }
        function load(name: string): void { Spaces.loadSetup(name ?? "") }
        function save(name: string): void { Spaces.saveSetup(name ?? "") }
        function remove(name: string): void { Spaces.deleteSetup(name ?? "") }
        function rename(from: string, to: string): bool { return Spaces.renameSetup(from ?? "", to ?? "") }
        function list():           string { return Spaces.setups.map(s => s.name).join("\n") }
    }

    IpcHandler {
        target: "volume"

        function up(step: string):   void { Audio.nudge((parseFloat(step) || 5) / 100) }
        function down(step: string): void { Audio.nudge(-(parseFloat(step) || 5) / 100) }
        function mute():             void { Audio.toggleMute() }
        function get():            string { return Math.round(Audio.volume * 100) + (Audio.muted ? " muted" : "") }
    }

    IpcHandler {
        target: "kbd"

        function up():             void { Kbd.up() }
        function down():           void { Kbd.down() }
        function cycle():          void { Kbd.cycle() }
        function set(n: string):   void { Kbd.set(parseInt(n) || 0) }
        function get():          string { return Kbd.available ? Kbd.level + "/" + Kbd.max + " " + Kbd.backend : "unavailable" }
    }

    IpcHandler {
        target: "bar"

        function toggle(): string { Sh.barHidden = !Sh.barHidden; return Sh.barEdge || "off" }
        function on():       void { Sh.barHidden = false }
        function off():      void { Sh.barHidden = true }
        function get():    string { return Sh.barEdge || "off" }
    }

    IpcHandler {
        target: "brightness"

        function up(step: string):   void { Brightness.nudge((parseFloat(step) || 5) / 100) }
        function down(step: string): void { Brightness.nudge(-(parseFloat(step) || 5) / 100) }
        function get():            string { return Math.round(Brightness.pct * 100) + "" }
    }
}
