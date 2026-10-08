import QtQuick
import "root:/modules"

// One workspace in miniature: every window where it sits on the monitor, with its icon and
// title. Clicking a window of the live layout focuses it.
Item {
    id: pv
    property var windows: []
    property bool live: false
    signal opened()

    readonly property var geo: Spaces.geometry(pv.windows.length ? pv.windows[0].monitor : "")
    readonly property real k: Math.min(pv.width / pv.geo.w, pv.height / pv.geo.h)

    Rectangle {
        id: screen
        anchors.centerIn: parent
        width: pv.geo.w * pv.k
        height: pv.geo.h * pv.k
        radius: DeckUi.innerRadius
        color: Qt.rgba(1, 1, 1, 0.025)
        border.width: 1
        border.color: DeckUi.line

        Repeater {
            model: pv.windows
            Rectangle {
                id: win
                required property var modelData
                readonly property real gap: DeckUi.f(2)
                x: (modelData.x - pv.geo.x) * pv.k + gap
                y: (modelData.y - pv.geo.y) * pv.k + gap
                z: modelData.floating ? 1 : 0
                width: Math.max(DeckUi.f(12), modelData.w * pv.k - gap * 2)
                height: Math.max(DeckUi.f(12), modelData.h * pv.k - gap * 2)
                radius: DeckUi.f(6)
                color: wma.containsMouse ? DeckUi.recessed : DeckUi.graphite
                border.width: 1
                border.color: modelData.focused ? DeckUi.selRim : DeckUi.rim
                Behavior on color { CAnim {} }

                AppIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: title.visible ? -DeckUi.f(7) : 0
                    width: Math.min(DeckUi.f(30), Math.min(win.width, win.height) * 0.45); height: width
                    icon: Spaces.icon(win.modelData.appid)
                    fallbackGlyph: Sh.icApp
                }
                Text {
                    id: title
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(8) }
                    visible: win.height > DeckUi.f(70) && win.width > DeckUi.f(70)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: win.modelData.title
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(10.5)
                }
                MouseArea {
                    id: wma
                    anchors.fill: parent
                    enabled: pv.live
                    hoverEnabled: pv.live
                    cursorShape: pv.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { Spaces.focus(win.modelData); pv.opened() }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: pv.windows.length === 0
            text: "Empty"
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12)
        }
    }
}
