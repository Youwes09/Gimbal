import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "root:/modules"

ShellRoot {
    id: shellRoot

    readonly property int _trayCount: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property int _batteryWatch: BatteryWatch.pct
    readonly property bool _idle: Idle.dark

    WallpaperWindow { }
    Overlay { id: overlay }
    LauncherWindow { id: launcher }
    DeckWindow { }
    NotificationToasts { }
    LaunchIndicator { }
    RecordingIndicator { }
    OsdIndicator { }
    RegionPicker { }

    IpcHandler {
        target: "deck"

        function toggle(): void { Sh.toggleDeck() }
        function open():   void { Sh.openDeck() }
        function close():  void { Sh.closeDeck() }
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

        function screenshot(mode: string): void { Capture.shot(mode ?? "region") }
        function record(mode: string):     void { Capture.recStart(mode ?? "full") }
        function stop():                   void { Capture.recStop() }
        function recordToggle():           void { Capture.recToggle() }
        function recording():            string { return Capture.recording ? "on" : "off" }
    }

    IpcHandler {
        target: "volume"

        function up(step: string):   void { Audio.nudge((parseFloat(step) || 5) / 100) }
        function down(step: string): void { Audio.nudge(-(parseFloat(step) || 5) / 100) }
        function mute():             void { Audio.toggleMute() }
        function get():            string { return Math.round(Audio.volume * 100) + (Audio.muted ? " muted" : "") }
    }

    IpcHandler {
        target: "brightness"

        function up(step: string):   void { Brightness.nudge((parseFloat(step) || 5) / 100) }
        function down(step: string): void { Brightness.nudge(-(parseFloat(step) || 5) / 100) }
        function get():            string { return Math.round(Brightness.pct * 100) + "" }
    }
}
