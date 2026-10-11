import QtQuick
import "root:/modules"

// Workspaces 1 through the last one in use, omarchy-spaces style: a block per workspace with
// its number and an icon per window, all on the same slot grid. An empty workspace holds a
// placeholder in its slot. When the row runs out of room, each block shows fewer icons and
// a "+N" slot. `active` is lifted; `selected` marks keyboard focus.
Rectangle {
    id: strip
    property var tags: []              // 9 lists of windows, as from Spaces.group()
    property int active: 0
    property int selected: 0
    property bool acceptsWindows: false  // blocks take windows dragged out of the preview
    signal picked(int tag)
    signal hovered(int tag)
    signal windowDropped(int tag, var window)

    property bool showAll: false       // all nine, e.g. as drop targets while dragging
    readonly property int count: strip.showAll ? 9 : Spaces.span(strip.tags, strip.active)

    readonly property real pad: DeckUi.f(5)
    readonly property real gap: DeckUi.f(6)
    readonly property real slot: DeckUi.f(28)
    readonly property real slotGap: DeckUi.f(6)
    readonly property real numW: DeckUi.f(14)
    readonly property real inset: DeckUi.f(10)

    // Most icons per block that still fits every block in the row.
    function _width(m) {
        let w = strip.pad * 2 + strip.gap * (strip.count - 1)
        for (let i = 0; i < strip.count; i++) {
            const n = Math.max(1, Math.min((strip.tags[i] || []).length, m))
            w += strip.inset * 2 + strip.numW + strip.slotGap + n * strip.slot + (n - 1) * strip.slotGap
        }
        return w
    }
    readonly property int maxIcons: {
        let m = 6
        while (m > 1 && strip._width(m) > strip.width) m--
        return m
    }

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
            model: strip.count
            Rectangle {
                id: block
                required property int index
                readonly property int tag: index + 1
                readonly property var wins: strip.tags[index] || []
                readonly property bool on: strip.active === block.tag
                readonly property bool sel: strip.selected === block.tag
                readonly property bool over: block.wins.length > strip.maxIcons
                readonly property var shown: block.wins.slice(0, block.over ? strip.maxIcons - 1 : strip.maxIcons)

                width: content.implicitWidth + strip.inset * 2
                height: strip.height - strip.pad * 2
                radius: DeckUi.f(9)
                color: drop.containsDrag ? Qt.alpha(DeckUi.accent, 0.18)
                     : block.on ? DeckUi.sel : bma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                border.color: block.sel || drop.containsDrag ? DeckUi.selRim : "transparent"
                Behavior on color { CAnim {} }
                Behavior on width { Anim {} }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: strip.slotGap

                    Text {
                        width: strip.numW
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: block.tag
                        color: block.on ? DeckUi.text : block.wins.length ? DeckUi.dim : DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(14)
                        font.weight: Font.Medium
                    }
                    Repeater {
                        model: block.shown
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: strip.slot; height: width
                            radius: DeckUi.f(7)
                            color: modelData.focused ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            AppIcon {
                                anchors.centerIn: parent
                                width: DeckUi.f(20); height: width
                                icon: Spaces.icon(parent.modelData.appid)
                                fallbackGlyph: Sh.icApp
                            }
                        }
                    }
                    // Placeholder for an empty workspace, or the overflow count.
                    Item {
                        visible: block.wins.length === 0 || block.over
                        anchors.verticalCenter: parent.verticalCenter
                        width: strip.slot; height: width
                        Text {
                            anchors.centerIn: parent
                            visible: block.wins.length === 0
                            text: Sh.icEmpty
                            color: DeckUi.faint
                            opacity: 0.6
                            font.family: Sh.iconFont
                            font.pixelSize: DeckUi.f(16)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: block.over
                            text: "+" + (block.wins.length - block.shown.length)
                            color: DeckUi.faint
                            font.family: DeckUi.mono
                            font.pixelSize: DeckUi.f(11.5)
                        }
                    }
                }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    enabled: strip.acceptsWindows
                    keys: ["gimbal-window"]
                    onDropped: (d) => strip.windowDropped(block.tag, d.source.modelData)
                }
                MouseArea {
                    id: bma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: strip.hovered(block.tag)
                    onClicked: strip.picked(block.tag)
                }
            }
        }
    }
}
