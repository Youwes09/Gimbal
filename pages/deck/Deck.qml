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
            focused: DeckUi.zone === "center"
            scale: 0.985 + 0.015 * deck.t
            opacity: deck.t

            // Rail
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
                        // Session sits at the bottom of the rail, like a settings cog.
                        y: index === deck.sections.length - 1 ? rail.height - height : index * (height + rail.spacing)
                        width: rail.width
                        height: width
                        radius: DeckUi.innerRadius
                        color: rb.on ? DeckUi.sel : rbMa.containsMouse ? DeckUi.hover : "transparent"
                        border.width: 1
                        border.color: rb.on ? DeckUi.selRim : "transparent"
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

    // ── key hints: what works right here ──────────────────────────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom
        anchors.topMargin: DeckUi.f(18)
        opacity: deck.t
        textFormat: Text.StyledText
        readonly property string dot: "<font color='" + Theme.accent + "'>  ·  </font>"
        readonly property string here: {
            const z = DeckUi.zone, s = DeckUi.section
            if (z === "sound") return "↑↓ pick · ←→ level · enter mute"
            if (z === "quick") return "arrows pick · enter toggle"
            if (z === "media") return "←→ pick · enter press"
            if (s === "notifications") return "↑↓ pick · enter open · del dismiss · c clear"
            if (s === "captures") return "arrows pick · enter open · c copy · del trash"
            if (s === "session") return "←→ pick · enter run"
            return "arrows pick · enter open"
        }
        text: "tab zone" + dot + "1–4 section" + dot + here + dot + "space play" + dot + "w wallpapers" + dot + "esc close"
        color: DeckUi.faint
        font.family: Sh.font
        font.pixelSize: DeckUi.f(11)
        font.letterSpacing: 0.5
    }
}
