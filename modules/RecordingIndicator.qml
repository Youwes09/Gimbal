import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

PanelWindow {
    id: win
    screen: Sh.focusedScreen
    color: "transparent"
    visible: win.up || fade.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-rec"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true }

    implicitWidth: Sh.sz("recording", 340)
    implicitHeight: Sh.sz("recording", 90) + Sh.barTop
    mask: Region {}

    property double elapsed: 0
    Timer {
        interval: 1000; repeat: true; running: Capture.recording; triggeredOnStart: true
        onTriggered: win.elapsed = Capture.recording ? (Date.now() - Capture.recStartAt) : 0
    }
    function _clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000))
        const m = Math.floor(s / 60)
        const ss = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (ss < 10 ? "0" : "") + ss
    }

    QtObject {
        id: errFlash
        property bool on: false
    }
    Timer { id: errHide; interval: 3200; onTriggered: errFlash.on = false }
    Connections {
        target: Capture
        function onErrorAtChanged() {
            errFlash.on = Capture.error.length > 0
            errHide.restart()
        }
    }

    // The bar shows recordings itself.
    readonly property bool up: (Capture.recording && Sh.barEdge === "") || errFlash.on

    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Sh.sz("recording", 20) + Sh.barTop
        height: Sh.sz("recording", 40)
        width: errFlash.on ? Sh.sz("recording", 280) : Math.min(row.implicitWidth + Sh.sz("recording", 30), Sh.sz("recording", 320))
        radius: Sh.sz("recording", 14)
        color: Theme.surface
        border.width: 1
        border.color: errFlash.on ? Qt.rgba(1, 0.4, 0.4, 0.5) : Qt.rgba(1, 0.3, 0.3, 0.5)

        opacity: win.up ? 1 : 0
        scale: win.up ? 1 : 0.94
        Behavior on opacity { Anim { id: fade } }
        Behavior on scale { Anim {} }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.9
            shadowVerticalOffset: Sh.sz("recording", 5)
            blurMax: 48
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Sh.sz("recording", 9)
            visible: !errFlash.on

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Sh.sz("recording", 9); height: Sh.sz("recording", 9); radius: width / 2
                color: Qt.rgba(1, 0.35, 0.35, 1)
                SequentialAnimation on opacity {
                    running: Capture.recording; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REC  " + win._clock(win.elapsed)
                color: Theme.fg
                font.family: Sh.font
                font.pixelSize: Sh.sz("recording", 13)
                font.weight: Font.Medium
                font.letterSpacing: 1
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.margins: Sh.sz("recording", 14)
            width: box.width - Sh.sz("recording", 28)
            visible: errFlash.on
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Capture.error
            color: Qt.rgba(1, 0.55, 0.55, 0.95)
            font.family: Sh.font
            font.pixelSize: Sh.sz("recording", 13)
            font.weight: Font.Medium
        }
    }
}
