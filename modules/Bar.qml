import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray as Tray
import "root:/modules"

// The bar (Config.bar): workspaces and the focused window, the clock, then tray and status.
PanelWindow {
    id: win
    readonly property bool onTop: Sh.barEdge !== "bottom"
    readonly property int shadowRoom: Sh.sz("bar", 14)

    visible: Sh.barEdge !== ""
    color: "transparent"
    anchors { left: true; right: true; top: win.onTop; bottom: !win.onTop }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "gimbal-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitHeight: Sh.barMargin + Sh.barHeight + win.shadowRoom
    exclusiveZone: Sh.barMargin + Sh.barHeight
    mask: Region { item: strip }


    Item {
        id: strip
        anchors { left: parent.left; right: parent.right }
        y: win.onTop ? 0 : win.shadowRoom
        height: Sh.barMargin + Sh.barHeight

        readonly property real ink: Sh.sz("bar", 12)
        readonly property real islandY: win.onTop ? Sh.barMargin : 0

        Island {
            id: left
            x: Sh.barMargin
            y: strip.islandY

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Sh.sz("bar", 3)
                Repeater {
                    model: Math.max(5, Spaces.span(Spaces.tags, Spaces.active))
                    Item {
                        id: ws
                        required property int index
                        readonly property int tag: index + 1
                        readonly property bool on: Spaces.active === ws.tag
                        readonly property bool used: (Spaces.tags[index] || []).length > 0
                        width: Sh.sz("bar", 16); height: Sh.barHeight
                        Rectangle {
                            anchors.centerIn: parent
                            width: ws.on ? Sh.sz("bar", 16) : Sh.sz("bar", 6)
                            height: Sh.sz("bar", 6)
                            radius: height / 2
                            color: ws.on ? Theme.accent
                                 : wsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.75)
                                 : ws.used ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.16)
                            Behavior on width { Anim {} }
                            Behavior on color { CAnim {} }
                        }
                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Spaces.view(ws.tag)
                        }
                    }
                }
            }

            Hairline { visible: focusRow.visible }

            Row {
                id: focusRow
                readonly property var w: Spaces.clients.find(c => c.focused && (c.tag === Spaces.active || c.tag === 0)) || null
                visible: w !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: Sh.sz("bar", 8)
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Sh.sz("bar", 15); height: width
                    icon: focusRow.w ? Spaces.icon(focusRow.w.appid) : ""
                    fallbackGlyph: Sh.icApp
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Sh.sz("bar", 320))
                    elide: Text.ElideRight
                    text: focusRow.w ? (focusRow.w.title || focusRow.w.appid) : ""
                    color: DeckUi.dim
                    font.family: Sh.font
                    font.pixelSize: strip.ink
                }
            }
        }

        Island {
            id: centre
            x: (strip.width - width) / 2
            y: strip.islandY
            hoverable: true
            onClicked: Sh.openDeck()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.time
                color: DeckUi.text
                font.family: Sh.font
                font.pixelSize: Sh.sz("bar", 13)
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.meridiem
                color: DeckUi.faint
                font.family: Sh.font
                font.pixelSize: Sh.sz("bar", 10.5)
                font.weight: Font.Medium
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Sh.sz("bar", 3); height: width; radius: width / 2
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Status.day.slice(0, 3) + " " + Status.date.split(" ")[1] + " " + Status.date.slice(0, 3)
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: strip.ink
            }
        }

        Island {
            id: right
            x: strip.width - width - Sh.barMargin
            y: strip.islandY

            Row {
                id: tray
                visible: Tray.SystemTray.items.values.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Sh.sz("bar", 4)
                Repeater {
                    model: Tray.SystemTray.items
                    Item {
                        id: ti
                        required property var modelData
                        width: Sh.sz("bar", 22); height: Sh.barHeight
                        Rectangle {
                            anchors.centerIn: parent
                            width: Sh.sz("bar", 22); height: width; radius: Sh.sz("bar", 6)
                            color: tiMa.containsMouse ? DeckUi.hover : "transparent"
                            Behavior on color { CAnim {} }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: Sh.sz("bar", 15); height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: ti.modelData.icon
                            smooth: true
                        }
                        MouseArea {
                            id: tiMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (e) => {
                                const m = ti.modelData
                                if (e.button === Qt.MiddleButton) m.secondaryActivate()
                                else if (e.button === Qt.RightButton || m.onlyMenu) {
                                    if (!m.hasMenu) return
                                    const p = ti.mapToItem(null, 0, win.onTop ? ti.height + Sh.sz("bar", 6) : -Sh.sz("bar", 6))
                                    m.display(win, p.x, p.y)
                                } else Compositor.focus([m.id, m.title, m.tooltipTitle])
                            }
                            onWheel: (e) => ti.modelData.scroll(e.angleDelta.y / 120, false)
                        }
                    }
                }
            }

            Hairline { visible: tray.visible }

            Glyph {
                visible: Status.player !== null
                glyph: Status.playing ? Sh.icPause : Sh.icPlay
                tint: Status.playing ? Theme.accent : DeckUi.dim
                label: Status.player ? Status.player.trackTitle : ""
                labelMax: Sh.sz("bar", 180)
                onClicked: if (Status.player) Status.player.togglePlaying()
            }

            Glyph {
                id: rec
                property int secs: 0
                visible: Capture.recording
                glyph: Sh.icRecord
                tint: DeckUi.danger
                label: Math.floor(rec.secs / 60) + ":" + String(rec.secs % 60).padStart(2, "0")
                onClicked: Capture.recStop()
                Timer {
                    interval: 1000; repeat: true; triggeredOnStart: true
                    running: Capture.recording
                    onTriggered: rec.secs = Math.max(0, Math.floor((Date.now() - Capture.recStartAt) / 1000))
                }
                SequentialAnimation on opacity {
                    running: Capture.recording; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.4; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Glyph {
                visible: Notifications.dnd
                glyph: Sh.icBellOff
                tint: Theme.accent
                onClicked: Notifications.toggleDnd()
            }

            Glyph {
                readonly property var link: Net.current
                glyph: !Net.wifiOn ? (Net.online ? Sh.icNetwork : Sh.icWifiOff)
                     : link ? Net.strengthGlyph(link.signalStrength)
                     : Net.online ? Sh.icNetwork : Sh.icWifiZero
                tint: Net.online || link ? DeckUi.text : DeckUi.faint
                onClicked: { DeckUi.openTo = "network"; Sh.openDeck() }
            }

            Glyph {
                visible: Net.devices.some(d => d.connected)
                glyph: Sh.icBluetoothOn
                onClicked: { DeckUi.openTo = "network"; Sh.openDeck() }
            }

            Glyph {
                glyph: Audio.muted || Audio.volume <= 0.001 ? Sh.icVolumeMute
                     : Audio.volume < 0.5 ? Sh.icVolumeLow : Sh.icVolumeHigh
                tint: Audio.muted ? DeckUi.faint : DeckUi.text
                onClicked: Audio.toggleMute()
                onScrolled: (d) => Audio.nudge(d * 0.05)
            }

            Glyph {
                visible: Status.hasBattery
                glyph: Sh.batteryGlyph(Status.pct, Status.charging)
                tint: Status.low ? DeckUi.danger : Status.charging ? DeckUi.good : DeckUi.text
                label: Status.pct + "%"
                onClicked: Sh.openDeck()
            }
        }
    }

    component Island: Rectangle {
        id: isl
        default property alias content: row.data
        property bool hoverable: false
        signal clicked()

        width: row.implicitWidth + Sh.sz("bar", 14) * 2
        height: Sh.barHeight
        radius: Sh.sz("bar", 11)
        color: isl.hoverable && islMa.containsMouse ? DeckUi.recessed : DeckUi.card
        border.width: 1
        border.color: DeckUi.rim
        Behavior on color { CAnim {} }
        Behavior on width { Anim {} }

        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: isl.radius
            blur: Sh.sz("bar", 16)
            offset.y: Sh.sz("bar", 3)
            color: Qt.rgba(0, 0, 0, 0.4)
        }
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: isl.radius * 0.6 }
            anchors.topMargin: 1
            height: 1
            color: DeckUi.sheen
        }
        MouseArea {
            id: islMa
            anchors.fill: parent
            enabled: isl.hoverable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: isl.clicked()
        }
        Row {
            id: row
            height: parent.height
            x: Sh.sz("bar", 14)
            spacing: Sh.sz("bar", 10)
        }
    }

    component Hairline: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Sh.sz("bar", 14)
        color: DeckUi.line
    }

    component Glyph: Item {
        id: g
        property string glyph: ""
        property color tint: DeckUi.text
        property string label: ""
        property real labelMax: Sh.sz("bar", 120)
        signal clicked()
        signal scrolled(int dir)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: gRow.implicitWidth + Sh.sz("bar", 10)
        height: Sh.sz("bar", 24)

        Rectangle {
            anchors.fill: parent
            radius: Sh.sz("bar", 7)
            color: gMa.containsMouse ? DeckUi.hover : "transparent"
            Behavior on color { CAnim {} }
        }
        Row {
            id: gRow
            anchors.centerIn: parent
            spacing: Sh.sz("bar", 6)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: g.glyph
                color: g.tint
                font.family: Sh.iconFont
                font.pixelSize: Sh.sz("bar", 13.5)
                Behavior on color { CAnim {} }
            }
            Text {
                visible: g.label.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, g.labelMax)
                elide: Text.ElideRight
                text: g.label
                color: DeckUi.dim
                font.family: Sh.font
                font.pixelSize: Sh.sz("bar", 12)
            }
        }
        MouseArea {
            id: gMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: g.clicked()
            onWheel: (e) => g.scrolled(e.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
