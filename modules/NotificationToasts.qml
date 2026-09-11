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

    readonly property int cardW: Sh.fs(452)
    readonly property int cardH: Sh.fs(74)
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

    function _strip(s) {
        return String(s || "")
            .replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"')
            .replace(/\s+/g, " ").trim()
    }
    function _iconSource(s) {
        if (!s || s.length === 0) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }

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
                NumberAnimation { property: "opacity"; from: 0; to: 1
                    duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: -win.cardH - Sh.fs(10)
                    duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.04 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.95; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { property: "y"; to: Sh.fs(10); duration: 220; easing.type: Easing.InCubic }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 240; easing.type: Easing.OutCubic }
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

                    Rectangle {
                        id: panel
                        anchors.fill: parent
                        radius: Sh.fs(14)
                        color: Theme.surface
                        border.width: 1
                        border.color: Qt.alpha(Theme.accent, 0.45)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.4)
                            shadowBlur: 0.9
                            shadowVerticalOffset: Sh.fs(7)
                            blurMax: 64
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Sh.fs(16)
                        anchors.rightMargin: Sh.fs(14)
                        spacing: Sh.fs(13)

                        AppIcon {
                            width: Sh.fs(27); height: Sh.fs(27)
                            anchors.verticalCenter: parent.verticalCenter
                            icon: card.model.appIcon
                            fallbackGlyph: Sh.icBell
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Sh.fs(27) - parent.spacing
                            spacing: Sh.fs(2)

                            Text {
                                width: parent.width
                                text: win._strip(card.model.summary) || String(card.model.app).toUpperCase()
                                color: Theme.fg
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: Sh.fs(14)
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: win._strip(card.model.body)
                                color: Theme.muted
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: Sh.fs(13)
                            }
                        }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.leftMargin: Sh.fs(14)
                        anchors.rightMargin: Sh.fs(14)
                        anchors.bottomMargin: Sh.fs(3)
                        height: Sh.fs(2)
                        radius: height / 2
                        color: Qt.alpha(Theme.fg, 0.06)
                        visible: card.front && !card.leaving && card.timeout > 0

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            radius: height / 2
                            color: Qt.alpha(Theme.accent, 0.6)
                            width: parent.width * Math.max(0, 1 - card.elapsed / card.timeout)
                            Behavior on width { NumberAnimation { duration: 60 } }
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
                    NumberAnimation {
                        id: snapBack
                        target: card; property: "dragX"; to: 0
                        duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1
                    }
                }
            }
        }
    }
}
