import QtQuick
import "root:/modules"

// A pill per workspace with its number and the apps open on it, omarchy-spaces style.
// `active` is lifted; `selected` marks keyboard focus.
Rectangle {
    id: strip
    property var tags: []              // 9 lists of windows, as from Spaces.group()
    property int active: 0
    property int selected: 0
    property int minCount: 5           // 1..minCount always show; 0 shows occupied ones only
    property int maxIcons: 4
    signal picked(int tag)
    signal hovered(int tag)

    readonly property var shown: {
        const used = []
        for (let i = 1; i <= 9; i++) if ((strip.tags[i - 1] || []).length) used.push(i)
        if (strip.minCount === 0) return used
        const n = Math.max(strip.minCount, used.length ? used[used.length - 1] : 0, strip.active)
        return Array.from({ length: n }, (_, i) => i + 1)
    }

    readonly property real pad: DeckUi.f(4)
    implicitWidth: row.implicitWidth + strip.pad * 2
    implicitHeight: DeckUi.f(46)
    radius: DeckUi.f(12)
    color: DeckUi.well
    border.width: 1
    border.color: DeckUi.line

    Row {
        id: row
        x: strip.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(4)

        Repeater {
            model: strip.shown
            Rectangle {
                id: pill
                required property int modelData
                readonly property var wins: strip.tags[modelData - 1] || []
                readonly property bool on: strip.active === modelData
                readonly property bool sel: strip.selected === modelData

                width: content.implicitWidth + DeckUi.f(20)
                height: strip.height - strip.pad * 2
                radius: DeckUi.f(9)
                color: pill.on ? DeckUi.sel : pma.containsMouse ? DeckUi.hover : "transparent"
                border.width: 1
                border.color: pill.sel ? DeckUi.selRim : "transparent"
                Behavior on color { CAnim {} }
                Behavior on width { Anim {} }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: DeckUi.f(6)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: pill.wins.length ? DeckUi.f(2) : 0
                        text: pill.modelData
                        color: pill.on ? DeckUi.text : pill.wins.length ? DeckUi.dim : DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(14)
                        font.weight: Font.Medium
                    }
                    Repeater {
                        model: pill.wins.slice(0, strip.maxIcons)
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: DeckUi.f(26); height: width
                            radius: DeckUi.f(6)
                            color: modelData.focused ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                            AppIcon {
                                anchors.centerIn: parent
                                width: DeckUi.f(20); height: width
                                icon: Spaces.icon(parent.modelData.appid)
                                fallbackGlyph: Sh.icApp
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.wins.length > strip.maxIcons
                        text: "+" + (pill.wins.length - strip.maxIcons)
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
                    onEntered: strip.hovered(pill.modelData)
                    onClicked: strip.picked(pill.modelData)
                }
            }
        }
    }
}
