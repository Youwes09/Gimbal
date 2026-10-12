import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

PanelWindow {
    id: win
    screen: Sh.focusedScreen
    color: "transparent"
    visible: Osd.kind !== "" || fade.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true }

    implicitWidth: Sh.sz("osd", 260)
    implicitHeight: Sh.sz("osd", 110)
    mask: Region {}

    readonly property bool up: Osd.kind !== ""
    readonly property bool isVol: Osd.kind === "volume"
    readonly property bool isKbd: Osd.kind === "kbd"
    readonly property real pct: isVol ? (Audio.muted ? 0 : Math.min(1, Audio.volume))
        : isKbd ? Kbd.pct : Brightness.pct
    readonly property string glyph: isVol
        ? (Audio.muted || Audio.volume <= 0.001 ? Sh.icVolumeMute
           : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh)
        : isKbd ? (Kbd.level === 0 ? Sh.icKeyboardOff : Sh.icKeyboard)
        : Sh.icSun

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sh.sz("osd", 28)
        width: Sh.sz("osd", 216)
        height: Sh.sz("osd", 52)
        radius: Sh.sz("osd", 16)
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.4)

        opacity: win.up ? 1 : 0
        scale: win.up ? 1 : 0.94
        Behavior on opacity { Anim { id: fade } }
        Behavior on scale { Anim {} }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.9
            shadowVerticalOffset: Sh.sz("osd", 6)
            blurMax: 48
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Sh.sz("osd", 16)
            anchors.rightMargin: Sh.sz("osd", 16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sh.sz("osd", 12)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: win.glyph
                color: win.pct <= 0.001 ? Theme.muted : Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: Sh.sz("osd", 18)
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Sh.sz("osd", 18) - Sh.sz("osd", 30) - parent.spacing * 2
                height: Sh.sz("osd", 5)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.1)

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * win.pct
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                    Behavior on width { Anim { duration: Motion.fast } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Sh.sz("osd", 30)
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.pct * 100) + "%"
                color: Theme.fg
                font.family: Sh.font
                font.pixelSize: Sh.sz("osd", 12)
                font.weight: Font.Medium
            }
        }
    }
}
