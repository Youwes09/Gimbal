import QtQuick
import "root:/modules"

// All nine workspaces as equal pills with the apps open on each, omarchy-spaces style.
// `active` is lifted; `selected` marks keyboard focus. Each pill shows as many icons as fit.
Rectangle {
    id: strip
    property var tags: []              // 9 lists of windows, as from Spaces.group()
    property int active: 0
    property int selected: 0
    signal picked(int tag)
    signal hovered(int tag)

    readonly property real pad: DeckUi.f(4)
    readonly property real gap: DeckUi.f(4)
    readonly property real pillW: (strip.width - strip.pad * 2 - strip.gap * 8) / 9
    readonly property real iconW: DeckUi.f(20)
    readonly property real step: DeckUi.f(14)          // icons overlap a little to fit more
    implicitHeight: DeckUi.f(46)
    radius: DeckUi.f(12)
    color: DeckUi.well
    border.width: 1
    border.color: DeckUi.line

    Row {
        x: strip.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: strip.gap

        Repeater {
            model: 9
            Rectangle {
                id: pill
                required property int index
                readonly property int tag: index + 1
                readonly property var wins: strip.tags[index] || []
                readonly property bool on: strip.active === pill.tag
                readonly property bool sel: strip.selected === pill.tag
                // Icons after the number; on overflow the last slot becomes "+N", keeping one icon.
                readonly property int fit: Math.max(1, Math.floor((strip.pillW - DeckUi.f(28) - strip.iconW) / strip.step) + 1)
                readonly property int shown: pill.wins.length > pill.fit ? Math.max(1, pill.fit - 1) : pill.wins.length

                width: strip.pillW
                height: strip.height - strip.pad * 2
                radius: DeckUi.f(9)
                color: pill.on ? DeckUi.sel : pma.containsMouse ? DeckUi.hover : "transparent"
                border.width: 1
                border.color: pill.sel ? DeckUi.selRim : "transparent"
                Behavior on color { CAnim {} }

                Row {
                    anchors.centerIn: parent
                    spacing: DeckUi.f(4)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: pill.wins.length ? DeckUi.f(2) : 0
                        text: pill.tag
                        color: pill.on ? DeckUi.text : pill.wins.length ? DeckUi.dim : DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(14)
                        font.weight: Font.Medium
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: strip.step - strip.iconW
                        Repeater {
                            model: pill.wins.slice(0, pill.shown)
                            AppIcon {
                                required property var modelData
                                required property int index
                                z: -index
                                width: strip.iconW; height: width
                                opacity: modelData.focused || !pill.on ? 1 : 0.75
                                icon: Spaces.icon(modelData.appid)
                                fallbackGlyph: Sh.icApp
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.wins.length > pill.shown
                        text: "+" + (pill.wins.length - pill.shown)
                        color: DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(11)
                    }
                }

                MouseArea {
                    id: pma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: strip.hovered(pill.tag)
                    onClicked: strip.picked(pill.tag)
                }
            }
        }
    }
}
