import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

PanelWindow {
    id: win
    color: "transparent"
    visible: Osd.kind !== "" || fade.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true }

    implicitWidth: Sh.fs(260)
    implicitHeight: Sh.fs(110)
    mask: Region {}

    readonly property bool up: Osd.kind !== ""
    readonly property bool isVol: Osd.kind === "volume"
    readonly property real pct: isVol ? (Audio.muted ? 0 : Math.min(1, Audio.volume)) : Brightness.pct
    readonly property string glyph: isVol
        ? (Audio.muted || Audio.volume <= 0.001 ? Sh.icVolumeMute
           : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh)
        : Sh.icSun

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sh.fs(28)
        width: Sh.fs(216)
        height: Sh.fs(52)
        radius: Sh.fs(16)
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.4)

        opacity: win.up ? 1 : 0
        scale: win.up ? 1 : 0.94
        Behavior on opacity { NumberAnimation { id: fade; duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.9
            shadowVerticalOffset: Sh.fs(6)
            blurMax: 48
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Sh.fs(16)
            anchors.rightMargin: Sh.fs(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sh.fs(12)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: win.glyph
                color: (win.isVol && (Audio.muted || Audio.volume <= 0.001)) ? Theme.muted : Theme.accent
                font.family: Sh.iconFont
                font.pixelSize: Sh.fs(18)
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Sh.fs(18) - Sh.fs(30) - parent.spacing * 2
                height: Sh.fs(5)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.1)

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * win.pct
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Sh.fs(30)
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.pct * 100) + "%"
                color: Theme.fg
                font.family: Sh.font
                font.pixelSize: Sh.fs(12)
                font.weight: Font.Medium
            }
        }
    }
}
