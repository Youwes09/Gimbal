import QtQuick
import Quickshell
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    function f(px) { return Sh.fs(px) }

    readonly property color fg:     Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted:  Qt.rgba(1, 1, 1, 0.5)
    readonly property color faint:  Qt.rgba(1, 1, 1, 0.26)
    readonly property color accent: Theme.accent

    readonly property int count: Notifications.historyModel.count
    property int selected: 0

    function cardH() { return root.f(82) }
    function gap()   { return root.f(12) }
    function step()  { return root.f(82) + root.f(12) }

    property bool _ready: false
    readonly property int half: 3
    property int centerIdx: 0

    onCountChanged: {
        root.selected = Math.max(0, Math.min(root.selected, root.count - 1))
        root._reflow()
    }
    onSelectedChanged: root._reflow()
    onHeightChanged: root._reflow()
    Component.onCompleted: {
        root._reflow()
        Qt.callLater(() => root._ready = true)
    }

    function _reflow() {
        if (root.count === 0) { strip.scrollY = root.height / 2; return }
        var lo = root.half
        var hi = root.count - 1 - root.half
        root.centerIdx = (hi < lo)
            ? Math.round((root.count - 1) / 2)
            : Math.max(lo, Math.min(hi, root.selected))
        strip.scrollY = root.height / 2 - root.cardH() / 2 - root.centerIdx * root.step()
    }


    function moveSel(d) {
        if (root.count === 0) return
        root.selected = Math.max(0, Math.min(root.count - 1, root.selected + d))
    }
    function actSel() {
        if (root.count === 0) return
        const r = Notifications.historyModel.get(root.selected)
        Notifications.focusSender(r)
        Notifications.invoke(r.nid, "")
        Notifications.dismiss(r.nid)
    }
    function dropSel() {
        if (root.count === 0) return
        Notifications.dismiss(Notifications.historyModel.get(root.selected).nid)
    }

    function _ago(ms) {
        const s = Math.max(0, Math.floor((Date.now() - ms) / 1000))
        if (s < 45) return "now"
        if (s < 3600) return Math.round(s / 60) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }
    function _strip(s) {
        return String(s || "").replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"')
            .replace(/\s+/g, " ").trim()
    }
    function _icon(s) {
        if (!s || s.length === 0) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }

    Item {
        id: sheet
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: fade.start()
        NumberAnimation {
            id: fade
            target: sheet; property: "opacity"; to: 1
            duration: 240; easing.type: Easing.OutCubic
        }

        Item {
            id: emptyState
            anchors.centerIn: parent
            width: root.f(120); height: root.f(120)
            opacity: root.count === 0 ? 1 : 0
            visible: opacity > 0.01
            scale: root.count === 0 ? 1 : 0.86
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }

            Text {
                anchors.centerIn: parent
                text: Notifications.dnd ? Sh.icBellOff : Sh.icBell
                color: Notifications.dnd ? root.accent : Qt.rgba(1, 1, 1, 0.3)
                font.family: Sh.iconFont
                font.pixelSize: root.f(60)
                Behavior on color { ColorAnimation { duration: 220 } }

                SequentialAnimation on scale {
                    running: emptyState.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.04; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.04; to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            id: strip
            width: Math.min(root.f(600), root.width * 0.44)
            x: (root.width - width) / 2
            opacity: root.count > 0 ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            property real scrollY: 0
            y: scrollY
            Behavior on y {
                enabled: root._ready
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            transform: Translate { id: rise; y: root.f(16) }
            Component.onCompleted: riseAnim.start()
            NumberAnimation {
                id: riseAnim
                target: rise; property: "y"; to: 0
                duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.2
            }

            Repeater {
                model: Notifications.historyModel

                delegate: Item {
                    id: card
                    required property int index
                    required property var model

                    width: strip.width
                    height: root.cardH()
                    y: index * root.step()

                    readonly property int dist: index - root.centerIdx
                    readonly property bool edge: Math.abs(card.dist) > root.half
                    visible: Math.abs(card.dist) <= root.half + 1

                    readonly property bool sel: index === root.selected
                    readonly property bool crit: model.urgency === "critical"
                    readonly property bool hot: card.sel || tap.containsMouse
                    property bool dying: false

                    opacity: card.dying ? 0 : (card.edge ? 0 : 1)
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    scale: card.dying ? 0.97 : (card.edge ? 0.955 : 1)
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    transform: Translate { x: card.dying ? root.f(42) : 0
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InCubic } } }

                    function go() {
                        if (card.dying) return
                        card.dying = true
                        gone.start()
                    }
                    Timer { id: gone; interval: 180; onTriggered: Notifications.dismiss(card.model.nid) }

                    Rectangle {
                        id: backing
                        anchors.fill: parent
                        radius: root.f(17)
                        color: Qt.rgba(0.09, 0.09, 0.10, card.crit ? 0.82 : 0.76)
                    }

                    Rectangle {
                        id: glass
                        anchors.fill: parent
                        radius: root.f(17)
                        gradient: Gradient {
                            GradientStop { position: 0.0
                                color: Qt.rgba(1, 1, 1, (card.crit ? 0.065 : 0.05) + (card.hot ? 0.02 : 0)) }
                            GradientStop { position: 0.5
                                color: Qt.rgba(1, 1, 1, (card.crit ? 0.05 : 0.038) + (card.hot ? 0.015 : 0)) }
                            GradientStop { position: 1.0
                                color: Qt.rgba(1, 1, 1, 0.032 + (card.hot ? 0.01 : 0)) }
                        }
                        border.width: card.crit ? 1.5 : 1
                        border.color: card.crit ? Qt.alpha(root.accent, 0.42)
                                                : Qt.rgba(1, 1, 1, card.hot ? 0.18 : 0.11)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.f(17)
                        color: Qt.alpha(root.accent, 0.07)
                        border.width: 1.5
                        border.color: Qt.alpha(root.accent, 0.75)
                        opacity: card.sel ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.margins: root.f(1)
                        height: root.f(1)
                        radius: height
                        color: Qt.rgba(1, 1, 1, card.hot ? 0.18 : 0.12)
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: root.f(20)
                        anchors.rightMargin: root.f(18)
                        spacing: root.f(15)

                        AppIcon {
                            width: root.f(32); height: root.f(32)
                            anchors.verticalCenter: parent.verticalCenter
                            icon: card.model.appIcon
                            fallbackGlyph: Sh.icBell
                            fallbackColor: card.crit ? root.accent : root.muted
                        }

                        Column {
                            id: textCol
                            width: parent.width - root.f(32) - parent.spacing - timeText.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.f(3)

                            Text {
                                width: parent.width
                                text: root._strip(card.model.summary) || String(card.model.app).toUpperCase()
                                color: root.fg
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: root.f(15)
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: root._strip(card.model.body)
                                color: root.muted
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: root.f(13)
                                lineHeight: 1.2
                            }
                        }

                        Text {
                            id: timeText
                            anchors.top: parent.top
                            text: root._ago(card.model.time)
                            color: root.faint
                            font.family: Sh.font
                            font.pixelSize: root.f(11)
                            font.letterSpacing: 1
                        }
                    }

                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selected = card.index
                            Notifications.focusSender(card.model)
                            Notifications.invoke(card.model.nid, "")
                            card.go()
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            textFormat: Text.StyledText
            text: {
                const a = "<font color='" + root.accent + "'>&middot;</font>"
                if (root.count === 0)
                    return Notifications.dnd ? "d  resume notifications" : "d  do not disturb"
                return "↑↓ select   " + a + "   enter open   " + a
                     + "   del dismiss   " + a + "   d dnd   " + a + "   c clear"
            }
            color: root.faint
            font.family: Sh.font
            font.pixelSize: root.f(12)
        }
    }
}
