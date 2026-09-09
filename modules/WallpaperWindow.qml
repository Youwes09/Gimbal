import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: win.modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "gimbal-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }
        color: "black"

        Component.onCompleted: Quickshell.execDetached(["pkill", "-x", "wbg"])

        WallSlide {
            anchors.fill: parent
            blurred: false
            fitW: win.screen ? win.screen.width : width
            fitH: win.screen ? win.screen.height : height
            path: Wallpapers.current
        }
    }
}
