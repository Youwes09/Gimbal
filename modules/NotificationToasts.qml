import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

PanelWindow {
    id: win
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true }

    readonly property int cardW: Sh.fs(492)
    readonly property int cardH: Sh.fs(84)
    readonly property int topGap: Sh.fs(16)
    readonly property int pad: Sh.fs(90)

    implicitWidth: cardW + pad * 2
    implicitHeight: topGap + cardH * 2 + Sh.fs(48)

    readonly property bool hasToast: Notifications.popupModel.count > 0 && !Sh.shown

    visible: hasToast || linger.running
    onHasToastChanged: if (hasToast) linger.stop(); else linger.restart()
    Timer { id: linger; interval: 340 }

    mask: win.hasToast ? toastRegion : emptyRegion
    Region { id: toastRegion; item: clipArea }
    Region { id: emptyRegion }

    Item {
        id: clipArea
        x: (win.width - win.cardW) / 2
        y: win.topGap
        width: win.cardW
        height: win.cardH

        ListView {
            id: stack
            width: parent.width
            height: win.cardH
            interactive: false
            clip: false
            model: Notifications.popupModel

            add: Transition {
                Anim { property: "opacity"; from: 0; to: 1 }
                Anim { property: "y"; from: -win.cardH - Sh.fs(10); duration: Motion.slow }
            }
            remove: Transition {
                AnimOut { property: "opacity"; to: 0 }
                AnimOut { property: "scale"; to: 0.96 }
            }
            displaced: Transition {
                Anim { property: "y" }
            }

            delegate: Item {
                id: card
                required property int index
                required property var model

                width: stack.width
                height: win.cardH
                z: -index

                readonly property bool front: index === 0
                readonly property int timeout: Notifications.timeoutFor(model.urgency)
                property real dragX: 0
                property real elapsed: 0
                property bool leaving: false

                function dismiss() {
                    if (card.leaving) return
                    card.leaving = true
                    Notifications.dismissPopup(card.model.nid)
                }

                Timer {
                    interval: 50; repeat: true
                    running: card.front && !card.leaving && card.timeout > 0
                             && !hover.hovered && card.dragX === 0
                    onTriggered: {
                        card.elapsed += interval
                        if (card.elapsed >= card.timeout) card.dismiss()
                    }
                }

                Item {
                    id: sheet
                    anchors.fill: parent
                    x: card.dragX
                    opacity: 1 - Math.min(0.9, Math.abs(card.dragX) / win.cardW)

                    RectangularShadow {
                        anchors.fill: panel
                        radius: panel.radius
                        blur: Sh.fs(36)
                        offset.y: Sh.fs(10)
                        spread: Sh.fs(1)
                        color: Qt.rgba(0, 0, 0, 0.55)
                    }
                    Rectangle {
                        id: panel
                        anchors.fill: parent
                        radius: Sh.fs(16)
                        color: DeckUi.card
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.13)
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: parent.radius }
                            anchors.topMargin: 1
                            height: 1
                            color: DeckUi.sheen
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: Sh.fs(14)
                        anchors.rightMargin: Sh.fs(16)
                        anchors.bottomMargin: Sh.fs(6)

                        Rectangle {
                            id: tile
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sh.fs(38); height: width
                            radius: Sh.fs(9)
                            color: DeckUi.graphite
                            border.width: 1
                            border.color: DeckUi.line
                            AppIcon {
                                anchors.centerIn: parent
                                width: Sh.fs(24); height: width
                                icon: card.model.appIcon
                                fallbackGlyph: Sh.icBell
                            }
                        }

                        Column {
                            anchors.left: tile.right
                            anchors.leftMargin: Sh.fs(12)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Sh.fs(3)

                            Item {
                                width: parent.width
                                height: summary.implicitHeight
                                Text {
                                    id: summary
                                    anchors.left: parent.left
                                    anchors.right: appName.left
                                    anchors.rightMargin: Sh.fs(10)
                                    text: Notifications.plain(card.model.summary) || String(card.model.app)
                                    color: DeckUi.text
                                    elide: Text.ElideRight
                                    font.family: DeckUi.sans
                                    font.pixelSize: Sh.fs(14)
                                    font.weight: Font.Medium
                                }
                                Text {
                                    id: appName
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(card.model.app || "")
                                    color: DeckUi.faint
                                    font.family: DeckUi.mono
                                    font.pixelSize: Sh.fs(11)
                                }
                            }
                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: Notifications.plain(card.model.body)
                                color: DeckUi.dim
                                elide: Text.ElideRight
                                font.family: DeckUi.sans
                                font.pixelSize: Sh.fs(12.5)
                            }
                        }
                    }

                    Rectangle {
                        id: track
                        visible: card.front && !card.leaving && card.timeout > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Sh.fs(64)
                        anchors.rightMargin: Sh.fs(16)
                        anchors.bottomMargin: Sh.fs(9)
                        height: Sh.fs(2)
                        radius: height / 2
                        color: DeckUi.line

                        readonly property real remainFrac: Math.max(0, 1 - card.elapsed / card.timeout)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * track.remainFrac
                            height: parent.height
                            radius: height / 2
                            color: DeckUi.accent
                        }
                    }

                    HoverHandler { id: hover }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            Notifications.focusSender(card.model)
                            Notifications.invoke(card.model.nid, "")
                            card.dismiss()
                        }
                    }

                    DragHandler {
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onActiveChanged: {
                            if (active) return
                            if (Math.abs(card.dragX) > win.cardW * 0.3) card.dismiss()
                            else snapBack.start()
                        }
                        onCentroidChanged: if (active)
                            card.dragX = centroid.position.x - centroid.pressPosition.x
                    }
                    Anim { id: snapBack; target: card; property: "dragX"; to: 0 }
                }
            }
        }
    }
}
