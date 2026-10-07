import QtQuick
import QtQuick.Effects
import "root:/modules"

// Three columns: at a glance | main panel with section rail | controls.
Item {
    id: deck

    property real t: 1   // reveal 0..1, drives the slide-in

    readonly property real gap:     DeckUi.f(14)
    readonly property real sideW:   DeckUi.f(290)
    readonly property real centerW: DeckUi.f(780)
    readonly property real h:       Math.min(DeckUi.f(620), height * 0.82)
    readonly property real totalW:  deck.sideW * 2 + deck.centerW + deck.gap * 2

    readonly property var sections: [
        { id: "home",          glyph: Sh.icHome,   label: "Home" },
        { id: "notifications", glyph: Sh.icBell,   label: "Notifications" },
        { id: "captures",      glyph: Sh.icImages, label: "Captures" },
        { id: "session",       glyph: Sh.icPower,  label: "Session" }
    ]

    Item {
        id: frame
        width: deck.totalW
        height: deck.h
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -DeckUi.f(10)

        // One soft shadow under all three columns.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 1.0
            shadowVerticalOffset: DeckUi.f(10)
            blurMax: 48
        }

        LeftColumn {
            x: (1 - deck.t) * -DeckUi.f(28)
            width: deck.sideW
            height: frame.height
            opacity: deck.t
        }

        // ── centre ──────────────────────────────────────────────────────
        Card {
            id: center
            x: deck.sideW + deck.gap
            width: deck.centerW
            height: frame.height
            focused: DeckUi.zone === "center" || DeckUi.zone === "rail"
            scale: 0.985 + 0.015 * deck.t
            opacity: deck.t

            // Rail: ↑↓ flip pages live, → or Enter steps into the page.
            Connections {
                target: DeckUi
                function onNav(key) {
                    if (DeckUi.zone !== "rail") return
                    const i = DeckUi.sections.indexOf(DeckUi.section), n = DeckUi.sections.length
                    if (key === Qt.Key_Up)    DeckUi.section = DeckUi.sections[Math.max(0, i - 1)]
                    if (key === Qt.Key_Down)  DeckUi.section = DeckUi.sections[Math.min(n - 1, i + 1)]
                    if (key === Qt.Key_Left)  DeckUi.go("left")
                    if (key === Qt.Key_Right || key === Qt.Key_Return || key === Qt.Key_Enter) DeckUi.go("right")
                }
            }

            Item {
                id: rail
                readonly property real spacing: DeckUi.f(8)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: DeckUi.f(12)
                width: DeckUi.f(44)

                Repeater {
                    model: deck.sections
                    Rectangle {
                        id: rb
                        required property var modelData
                        required property int index
                        readonly property bool on: DeckUi.section === modelData.id
                        readonly property bool kb: rb.on && DeckUi.zone === "rail"
                        // Session sits at the bottom of the rail, like a settings cog.
                        y: index === deck.sections.length - 1 ? rail.height - height : index * (height + rail.spacing)
                        width: rail.width
                        height: width
                        radius: DeckUi.innerRadius
                        color: rb.kb ? Qt.alpha(Theme.accent, 0.22) : rb.on ? DeckUi.sel : rbMa.containsMouse ? DeckUi.hover : "transparent"
                        border.width: 1
                        border.color: rb.kb ? Theme.accent : rb.on ? Qt.alpha(Theme.accent, 0.25) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: rb.modelData.glyph
                            color: rb.on ? Theme.accent : DeckUi.dim
                            font.family: Sh.iconFont
                            font.pixelSize: DeckUi.f(17)
                        }
                        // Unread badge on notifications.
                        Rectangle {
                            visible: rb.modelData.id === "notifications" && Notifications.historyModel.count > 0
                            anchors { right: parent.right; top: parent.top; margins: DeckUi.f(6) }
                            width: Math.max(DeckUi.f(15), badge.implicitWidth + DeckUi.f(8))
                            height: DeckUi.f(15)
                            radius: height / 2
                            color: Theme.accent
                            Text {
                                id: badge
                                anchors.centerIn: parent
                                text: Math.min(99, Notifications.historyModel.count)
                                color: Theme.bg
                                font.family: Sh.font
                                font.pixelSize: DeckUi.f(9)
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: DeckUi.f(4)
                            text: rb.index + 1
                            color: DeckUi.faint
                            font.family: Sh.font
                            font.pixelSize: DeckUi.f(8.5)
                        }
                        MouseArea {
                            id: rbMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { DeckUi.section = rb.modelData.id; DeckUi.zone = "center" }
                        }
                    }
                }
            }
            Rectangle {
                anchors { left: rail.right; leftMargin: DeckUi.f(12); top: parent.top; bottom: parent.bottom; margins: DeckUi.f(14) }
                width: 1
                color: DeckUi.line
            }

            // Sections, cross-faded. Each is built only while it's showing.
            Item {
                id: body
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                anchors.leftMargin: DeckUi.f(36)
                anchors.margins: DeckUi.f(24)

                component Section: Loader {
                    property string sid: ""
                    anchors.fill: parent
                    active: DeckUi.section === sid || opacity > 0.01
                    opacity: DeckUi.section === sid ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Section { sid: "home";          sourceComponent: Home {} }
                Section { sid: "notifications"; sourceComponent: Notifs {} }
                Section { sid: "captures";      sourceComponent: Captures {} }
                Section { sid: "session";       sourceComponent: Session {} }
            }
        }

        RightColumn {
            x: deck.sideW + deck.gap + deck.centerW + deck.gap + (1 - deck.t) * DeckUi.f(28)
            width: deck.sideW
            height: frame.height
            opacity: deck.t
        }
    }

    // ── key hints: chips for what works right here, then the constants ─
    Row {
        id: hints
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom
        anchors.topMargin: DeckUi.f(20)
        spacing: DeckUi.f(18)
        opacity: deck.t

        readonly property var here: {
            const z = DeckUi.zone, s = DeckUi.section
            if (z === "mixer") return [["←→", "level"], ["⏎", "mute"]]
            if (z === "quick") return [["⏎", "toggle"]]
            if (z === "media") return Status.player ? [["←→", "pick"], ["⏎", "press"]] : []
            if (z === "rail")  return [["↑↓", "page"], ["⏎", "enter"]]
            if (s === "notifications") return [["⏎", "open"], ["del", "dismiss"], ["c", "clear all"]]
            if (s === "captures") return [["⏎", "open"], ["c", "copy"], ["del", "trash"]]
            if (s === "session") return [["⏎", "run"]]
            return [["⏎", "open"]]
        }
        readonly property var always: [["←↑↓→", "move"], ["tab", "page"]]
            .concat(Status.player ? [["space", "play"]] : [])
            .concat([["esc", "close"]])

        Repeater {
            model: (hints.here.length ? hints.here.concat([null]) : []).concat(hints.always)
            Item {
                id: hint
                required property var modelData
                implicitWidth: modelData ? hintRow.implicitWidth : DeckUi.f(1)
                implicitHeight: DeckUi.f(22)
                // A null entry is the divider between contextual and constant keys.
                Rectangle {
                    visible: !hint.modelData
                    anchors.centerIn: parent
                    width: 1; height: DeckUi.f(14)
                    color: DeckUi.line
                }
                Row {
                    id: hintRow
                    visible: !!hint.modelData
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: DeckUi.f(7)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(height, keyText.implicitWidth + DeckUi.f(12))
                        height: DeckUi.f(20)
                        radius: DeckUi.f(5)
                        color: Qt.alpha(Theme.fg, 0.07)
                        border.width: 1
                        border.color: Qt.alpha(Theme.fg, 0.12)
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: hint.modelData ? hint.modelData[0] : ""
                            color: Theme.fg
                            font.family: Sh.font
                            font.pixelSize: DeckUi.f(10)
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hint.modelData ? hint.modelData[1] : ""
                        color: DeckUi.dim
                        font.family: Sh.font
                        font.pixelSize: DeckUi.f(11)
                    }
                }
            }
        }
    }
}
