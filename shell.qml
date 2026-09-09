import Quickshell
import Quickshell.Io
import "root:/modules"

ShellRoot {
    id: shellRoot

    WallpaperWindow { }
    Overlay { id: overlay }
    LauncherWindow { id: launcher }

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
}
