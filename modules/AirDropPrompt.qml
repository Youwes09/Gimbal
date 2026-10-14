import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"

// An AirDrop transfer waiting for an answer: who, what, the sender's preview, and how long until
// it's declined for you. It never takes the keyboard on its own, so a request that lands while
// you type can't be accepted by accident; click it first, then ⏎ accepts and esc declines.
PanelWindow {
    id: win
    screen: Sh.focusedScreen
    color: "transparent"

    readonly property var req: AirDrop.asks.length ? AirDrop.asks[0] : null
    visible: !!win.req

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal-airdrop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true }

    function s(px) { return Sh.sz("notifications", px) }
    readonly property int cardW: win.s(492)
    readonly property int cardH: win.s(150)
    // Below a notification toast, if one is up.
    readonly property int topGap: win.s(16) + Sh.barTop
        + (Notifications.popupModel.count > 0 && !Sh.shown ? win.s(84) + win.s(12) : 0)
    implicitWidth: win.cardW + win.s(90) * 2
    implicitHeight: win.topGap + win.cardH + win.s(48)
    mask: Region { item: card }

    property real now: Date.now()
    Timer { interval: 250; repeat: true; running: win.visible; onTriggered: win.now = Date.now() }
    readonly property real left: win.req ? Math.max(0, win.req.deadline * 1000 - win.now) : 0

    // The bar drains on its own animation, from the share of the wait left when the request
    // arrived; the countdown text ticks with `now`.
    property real share: 0
    readonly property real _wait: 30000
    NumberAnimation { id: drain; target: win; property: "share"; to: 0 }
    onReqChanged: {
        drain.stop()
        if (!win.req) return
        const ms = Math.max(0, win.req.deadline * 1000 - Date.now())
        win.share = Math.min(1, ms / win._wait)
        drain.duration = ms
        drain.start()
    }

    readonly property string what: {
        const r = win.req
        if (!r) return ""
        if (r.links && r.links.length) return r.links.length === 1 ? r.links[0] : r.links.length + " links"
        const total = r.files.reduce((a, f) => a + (f.size || 0), 0)
        const name = r.files.length === 1 ? r.files[0].name : r.files.length + " files"
        return name + (total ? "  ·  " + Net.bytes(total) : "")
    }

    Item {
        id: card
        x: (win.width - win.cardW) / 2
        y: win.topGap
        width: win.cardW
        height: win.cardH
        focus: true
        Keys.onReturnPressed: if (win.req) AirDrop.answer(win.req.id, "accept")
        Keys.onEnterPressed: if (win.req) AirDrop.answer(win.req.id, "accept")
        Keys.onEscapePressed: if (win.req) AirDrop.answer(win.req.id, "decline")

        RectangularShadow {
            anchors.fill: panel
            radius: panel.radius
            blur: win.s(36)
            offset.y: win.s(10)
            spread: win.s(1)
            color: Qt.rgba(0, 0, 0, 0.55)
        }
        Rectangle {
            id: panel
            anchors.fill: parent
            radius: win.s(16)
            color: DeckUi.card
            border.width: 1
            border.color: Qt.alpha(DeckUi.accent, 0.45)
        }

        // The sender's preview, or a file glyph without one.
        Rectangle {
            id: thumb
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: win.s(14) }
            width: height
            radius: win.s(10)
            color: DeckUi.graphite
            clip: true
            Image {
                anchors.fill: parent
                visible: status === Image.Ready
                source: win.req && win.req.preview ? "file://" + win.req.preview : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            Text {
                anchors.centerIn: parent
                visible: !(win.req && win.req.preview)
                text: win.req && win.req.links && win.req.links.length ? Sh.icGlobe : Sh.icFile
                color: DeckUi.dim
                font.family: Sh.iconFont
                font.pixelSize: win.s(30)
            }
        }

        Column {
            anchors { left: thumb.right; right: parent.right; top: parent.top
                      leftMargin: win.s(14); rightMargin: win.s(16); topMargin: win.s(16) }
            spacing: win.s(3)
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: win.req ? win.req.sender || "Someone nearby" : ""
                color: DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: win.s(14)
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                elide: Text.ElideMiddle
                text: "wants to send " + win.what
                color: DeckUi.dim
                font.family: DeckUi.sans
                font.pixelSize: win.s(12.5)
            }
            Text {
                text: "Declines in " + Math.ceil(win.left / 1000) + " s"
                color: DeckUi.faint
                font.family: DeckUi.mono
                font.pixelSize: win.s(11)
            }
        }

        component Choice: Rectangle {
            property string label
            property bool primary: false
            signal picked()
            implicitWidth: lbl.implicitWidth + win.s(24)
            height: win.s(30)
            radius: win.s(8)
            color: primary ? DeckUi.accent : ma.containsMouse ? DeckUi.hover : DeckUi.well
            border.width: 1
            border.color: primary ? "transparent" : DeckUi.line
            Text {
                id: lbl
                anchors.centerIn: parent
                text: parent.label
                color: parent.primary ? DeckUi.accentInk : DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: win.s(12.5)
                font.weight: Font.Medium
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.picked() }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: win.s(14) }
            spacing: win.s(8)
            Choice { label: "Decline"; onPicked: AirDrop.answer(win.req.id, "decline") }
            // Only for a sender who proved who they are; adds them to your known senders.
            Choice {
                visible: !!win.req && win.req.hashes.length > 0
                label: "Always accept"
                onPicked: AirDrop.answer(win.req.id, "always")
            }
            Choice { label: "Accept"; primary: true; onPicked: AirDrop.answer(win.req.id, "accept") }
        }

        // Time left before it's declined for you.
        Rectangle {
            anchors { left: thumb.right; right: parent.right; bottom: parent.bottom
                      leftMargin: win.s(14); rightMargin: win.s(16); bottomMargin: win.s(6) }
            height: win.s(2)
            radius: height / 2
            color: DeckUi.line
            Rectangle {
                width: parent.width * win.share
                height: parent.height
                radius: parent.radius
                color: DeckUi.accent
            }
        }
    }
}
