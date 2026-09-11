import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/modules"

Variants {
    model: Capture.pickerActive ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gimbal-region"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }

        property real x0: 0
        property real y0: 0
        property bool dragging: false

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.32)
        }

        Rectangle {
            visible: win.dragging
            x: Math.min(win.x0, ma.mouseX)
            y: Math.min(win.y0, ma.mouseY)
            width: Math.abs(ma.mouseX - win.x0)
            height: Math.abs(ma.mouseY - win.y0)
            color: Qt.rgba(0.56, 0.9, 0.66, 0.14)
            border.width: 1.5
            border.color: Qt.rgba(0.56, 0.9, 0.66, 0.9)

            Rectangle {
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: dimText.implicitWidth + 12
                height: dimText.implicitHeight + 6
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.7)
                visible: parent.width > 2 && parent.height > 2

                Text {
                    id: dimText
                    anchors.centerIn: parent
                    text: Math.round(parent.parent.width) + " × " + Math.round(parent.parent.height)
                    color: "white"
                    font.family: Sh.font
                    font.pixelSize: Sh.fs(12)
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: (m) => { win.dragging = true; win.x0 = m.x; win.y0 = m.y }
            onReleased: (m) => {
                win.dragging = false
                const gx = win.screen.x + Math.min(win.x0, m.x)
                const gy = win.screen.y + Math.min(win.y0, m.y)
                const gw = Math.abs(m.x - win.x0)
                const gh = Math.abs(m.y - win.y0)
                Capture._regionPicked(gx, gy, gw, gh)
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Capture._regionCancelled()
        }
    }
}
