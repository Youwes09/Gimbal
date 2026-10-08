import QtQuick
import "root:/modules"

// One workspace in miniature: every window where it sits on the monitor, with its icon and
// title. Live windows can be clicked to focus, closed, or dragged onto a workspace pill.
Item {
    id: pv
    property var windows: []
    property bool live: false
    property Item dragLayer: pv          // a dragged window is lifted here, above the strips
    readonly property bool dragging: pv._drag !== null
    property var _drag: null
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
            Item {
                id: slot
                required property var modelData
                readonly property real gap: DeckUi.f(2)
                x: (modelData.x - pv.geo.x) * pv.k + gap
                y: (modelData.y - pv.geo.y) * pv.k + gap
                z: modelData.floating ? 1 : 0
                width: Math.max(DeckUi.f(12), modelData.w * pv.k - gap * 2)
                height: Math.max(DeckUi.f(12), modelData.h * pv.k - gap * 2)

                Rectangle {
                    id: win
                    width: slot.width
                    height: slot.height
                    radius: DeckUi.f(6)
                    clip: true
                    color: wma.containsMouse ? DeckUi.recessed : DeckUi.graphite
                    border.width: 1
                    border.color: slot.modelData.focused || wma.containsMouse ? DeckUi.selRim : DeckUi.rim
                    opacity: Drag.active ? 0.9 : 1
                    scale: Drag.active ? Math.min(1, DeckUi.f(120) / Math.max(width, height)) : 1
                    Behavior on color { CAnim {} }
                    Behavior on scale { Anim {} }

                    Drag.active: wma.drag.active
                    Drag.keys: ["gimbal-window"]
                    Drag.source: slot

                    AppIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: title.visible ? -DeckUi.f(7) : 0
                        width: Math.min(DeckUi.f(30), Math.min(win.width, win.height) * 0.45)
                        height: width
                        icon: Spaces.icon(slot.modelData.appid)
                        fallbackGlyph: Sh.icApp
                    }
                    Text {
                        id: title
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: DeckUi.f(8) }
                        visible: win.height > DeckUi.f(70) && win.width > DeckUi.f(70)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: slot.modelData.title
                        color: DeckUi.faint
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(10.5)
                    }

                    MouseArea {
                        id: wma
                        anchors.fill: parent
                        enabled: pv.live
                        hoverEnabled: pv.live
                        cursorShape: drag.active ? Qt.ClosedHandCursor : pv.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                        drag.target: win
                        drag.threshold: DeckUi.f(6)
                        onPressed: (m) => { win.Drag.hotSpot.x = m.x; win.Drag.hotSpot.y = m.y }
                        onClicked: { Spaces.focus(slot.modelData); pv.opened() }
                        drag.onActiveChanged: {
                            if (drag.active) {
                                pv._drag = slot.modelData
                                const p = win.mapToItem(pv.dragLayer, 0, 0)
                                win.parent = pv.dragLayer
                                win.x = p.x; win.y = p.y
                                return
                            }
                            win.Drag.drop()
                            pv._drag = null
                            win.parent = slot
                            win.x = 0; win.y = 0
                        }
                    }

                    // Close
                    Rectangle {
                        anchors { right: parent.right; top: parent.top; margins: DeckUi.f(5) }
                        visible: pv.live && (wma.containsMouse || xma.containsMouse) && !win.Drag.active
                                 && win.width > DeckUi.f(44) && win.height > DeckUi.f(30)
                        width: DeckUi.f(20); height: width
                        radius: DeckUi.f(5)
                        color: xma.containsMouse ? DeckUi.danger : Qt.rgba(0, 0, 0, 0.55)
                        Behavior on color { CAnim {} }
                        Text {
                            anchors.centerIn: parent
                            text: Sh.icX
                            color: "white"
                            font.family: Sh.iconFont
                            font.pixelSize: DeckUi.f(12)
                        }
                        MouseArea {
                            id: xma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Spaces.closeWindow(slot.modelData)
                        }
                    }
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
