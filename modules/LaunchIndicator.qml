import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

PanelWindow {
    id: win
    color: "transparent"
    visible: Launches.phase !== "" || fade.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-launch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true }

    implicitWidth: Sh.fs(420)
    implicitHeight: Sh.fs(120)
    mask: Region {}

    readonly property bool up: Launches.phase !== ""

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sh.fs(28)
        height: Sh.fs(46)
        width: row.implicitWidth + Sh.fs(34)
        radius: Sh.fs(15)
        color: Theme.surface
        border.width: 1
        border.color: Launches.phase === "killed" ? Qt.rgba(1, 0.4, 0.4, 0.5) : Qt.alpha(Theme.accent, 0.4)

        opacity: win.up ? 1 : 0
        scale: win.up ? 1 : 0.94
        Behavior on opacity { Anim { id: fade } }
        Behavior on scale { Anim {} }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.9
            shadowVerticalOffset: Sh.fs(6)
            blurMax: 48
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Sh.fs(11)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Launches.phase === "ok" ? Sh.icCorner
                    : Launches.phase === "killed" ? Sh.icX
                    : Sh.icRefresh
                color: Launches.phase === "killed" ? Qt.rgba(1, 0.55, 0.55, 0.95) : Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: Sh.fs(15)
                RotationAnimation on rotation {
                    from: 0; to: 360; duration: 850
                    loops: Animation.Infinite
                    running: Launches.phase === "starting"
                    alwaysRunToEnd: true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Launches.phase === "ok" ? (Launches.title + " ready")
                    : Launches.phase === "killed" ? (Launches.title + " killed")
                    : Launches.slow ? (Launches.title + " — still starting…")
                    : ("Launching " + Launches.title + "…")
                color: Theme.fg
                font.family: Sh.font
                font.pixelSize: Sh.fs(13)
                font.weight: Font.Medium
            }
        }
    }
}
