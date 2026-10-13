import QtQuick
import Quickshell
import "root:/modules"

// The compositor's key binds, grouped. ↑↓ scroll · enter opens the config.
Item {
    id: keys

    Component.onCompleted: Keybinds.refresh()

    function edit() { Sh.closeDeck(); Quickshell.execDetached([Config.editor, Keybinds.path]) }

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "keys") return
            const step = DeckUi.f(120)
            if (key === Qt.Key_Up)    flick.contentY = Math.max(0, flick.contentY - step)
            if (key === Qt.Key_Down)  flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + step))
            if (key === Qt.Key_Left)  DeckUi.go("left")
            if (key === Qt.Key_Right) DeckUi.go("right")
            if (key === Qt.Key_Return || key === Qt.Key_Enter) keys.edit()
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "Keybinds"
        detail: Keybinds.total + " binds  ·  " + Keybinds.path.replace(Quickshell.env("HOME"), "~")
        Button {
            glyph: Sh.icPencil
            label: "Edit"
            selected: DeckUi.zone === "center"
            onClicked: keys.edit()
        }
    }

    // Groups go to whichever column is shorter, so the two stay even.
    readonly property var columns: {
        const cols = [[], []], h = [0, 0]
        for (const g of Keybinds.groups) {
            const c = h[0] <= h[1] ? 0 : 1
            cols[c].push(g)
            h[c] += g.binds.length + 2
        }
        return cols
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(16)
        contentHeight: cols.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { Anim {} }

        Row {
            id: cols
            width: flick.width
            spacing: DeckUi.f(28)
            Repeater {
                model: keys.columns
                Column {
                    id: column
                    required property var modelData
                    width: (cols.width - cols.spacing) / 2
                    spacing: DeckUi.f(18)
                    Repeater {
                        model: column.modelData
                        Column {
                            id: group
                            required property var modelData
                            width: column.width
                            spacing: DeckUi.f(2)
                            Caption { width: parent.width; text: group.modelData.name; height: DeckUi.f(22) }
                            Repeater {
                                model: group.modelData.binds
                                Item {
                                    id: bind
                                    required property var modelData
                                    width: group.width
                                    height: DeckUi.f(28)
                                    Text {
                                        anchors { left: parent.left; right: caps.left; rightMargin: DeckUi.f(12); verticalCenter: parent.verticalCenter }
                                        elide: Text.ElideRight
                                        textFormat: Text.StyledText
                                        text: bind.modelData.label + (bind.modelData.detail
                                            ? "  <font color='" + DeckUi.faint + "'>" + bind.modelData.detail.replace(/</g, "&lt;") + "</font>" : "")
                                        color: DeckUi.text
                                        font.family: DeckUi.sans
                                        font.pixelSize: DeckUi.f(12)
                                    }
                                    Row {
                                        id: caps
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        spacing: DeckUi.f(4)
                                        Repeater {
                                            model: bind.modelData.keys
                                            Rectangle {
                                                id: cap
                                                required property string modelData
                                                width: Math.max(height, capText.implicitWidth + DeckUi.f(12))
                                                height: DeckUi.f(20)
                                                radius: DeckUi.f(5)
                                                color: DeckUi.graphite
                                                border.width: 1
                                                border.color: DeckUi.rim
                                                Text {
                                                    id: capText
                                                    anchors.centerIn: parent
                                                    text: cap.modelData
                                                    color: DeckUi.text
                                                    font.family: DeckUi.mono
                                                    font.pixelSize: DeckUi.f(10)
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: flick
        visible: Keybinds.groups.length === 0
        text: "No binds found in " + Keybinds.path.replace(Quickshell.env("HOME"), "~")
        color: DeckUi.faint
        font.family: DeckUi.sans
        font.pixelSize: DeckUi.f(12)
    }
}
