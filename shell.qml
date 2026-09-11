import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "root:/modules"

ShellRoot {
    id: shellRoot

    readonly property int _trayCount: SystemTray.items ? SystemTray.items.values.length : 0

    WallpaperWindow { }
    Overlay { id: overlay }
    LauncherWindow { id: launcher }
    NotificationToasts { }
    LaunchIndicator { }
    RecordingIndicator { }
    RegionPicker { }

    IpcHandler {
        target: "overlay"

        function toggle(page: string): void { Sh.toggle(page ?? "") }
        function open(page: string):   void { Sh.open(page ?? "") }
        function close():              void { Sh.close() }
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

        function toggle(): void { Sh.toggle("notifications") }
        function open():   void { Sh.open("notifications") }
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
        function annotate():               void { Capture.annotate() }
        function recording():            string { return Capture.recording ? "on" : "off" }
    }
}
