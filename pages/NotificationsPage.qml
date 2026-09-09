import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    function f(px) { return Sh.fs(px) }

    readonly property var items: {
        const h = Notifications.history.slice()
        h.sort((a, b) => a.app === b.app ? b.time - a.time : a.app.localeCompare(b.app))
        return h
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
            .replace(/\s+/g, " ").trim()
    }
    function _icon(s) {
        if (!s || s.length === 0) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }

    Item {
        id: panelWrap
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        width: Math.min(root.f(660), parent.width * 0.5)
        height: Math.min(root.f(620), parent.height * 0.68)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.42)
            shadowBlur: 1.0
            shadowVerticalOffset: root.f(12)
            blurMax: 64
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: root.f(18)
            color: Theme.surface
            clip: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: root.f(56)

                Text {
                    anchors { left: parent.left; leftMargin: root.f(20); verticalCenter: parent.verticalCenter }
                    text: "NOTIFICATIONS"
                    color: Theme.muted
                    font.family: Sh.font
                    font.pixelSize: root.f(12)
                    font.letterSpacing: 1.5
                }

                Row {
                    anchors { right: parent.right; rightMargin: root.f(14); verticalCenter: parent.verticalCenter }
                    spacing: root.f(8)

                    Rectangle {
                        width: dndRow.implicitWidth + root.f(18)
                        height: root.f(28)
                        radius: root.f(8)
                        color: Notifications.dnd ? Qt.alpha(Theme.accent, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Notifications.dnd ? Qt.alpha(Theme.accent, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                        Row {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: root.f(6)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Notifications.dnd ? Sh.icBellOff : Sh.icBell
                                color: Notifications.dnd ? Theme.accent : Theme.muted
                                font.family: Sh.iconFont
                                font.pixelSize: root.f(13)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Notifications.dnd ? "DND on" : "DND"
                                color: Notifications.dnd ? Theme.accent : Theme.muted
                                font.family: Sh.font
                                font.pixelSize: root.f(11)
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: Notifications.toggleDnd() }
                    }

                    Rectangle {
                        width: clrText.implicitWidth + root.f(18)
                        height: root.f(28)
                        radius: root.f(8)
                        visible: root.items.length > 0
                        color: clrArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        Text {
                            id: clrText
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Theme.muted
                            font.family: Sh.font
                            font.pixelSize: root.f(11)
                        }
                        MouseArea {
                            id: clrArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Notifications.clearAll()
                        }
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Theme.rim
                }
            }

            ListView {
                id: list
                anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.margins: root.f(6)
                clip: true
                model: root.items
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0

                section.property: "app"
                section.delegate: Item {
                    width: list.width
                    height: root.f(30)
                    Row {
                        anchors { left: parent.left; leftMargin: root.f(14); verticalCenter: parent.verticalCenter }
                        spacing: root.f(8)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: section.toUpperCase()
                            color: Theme.muted
                            font.family: Sh.font
                            font.pixelSize: root.f(10)
                            font.letterSpacing: 1
                        }
                    }
                }

                delegate: Item {
                    id: row
                    width: list.width
                    height: Math.max(root.f(54), col.implicitHeight + root.f(18))

                    readonly property var live: Notifications._live(modelData.nid)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: root.f(9)
                        color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: root.f(14)
                        anchors.rightMargin: root.f(12)
                        spacing: root.f(12)

                        Item {
                            width: root.f(28); height: root.f(28)
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: ic
                                anchors.fill: parent
                                source: root._icon(modelData.appIcon)
                                visible: source.toString().length > 0 && status === Image.Ready
                                sourceSize.width: 56; sourceSize.height: 56
                                smooth: true; mipmap: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !ic.visible
                                text: Sh.icBell
                                color: Theme.muted
                                font.family: Sh.iconFont
                                font.pixelSize: root.f(15)
                            }
                        }

                        Column {
                            id: col
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - root.f(28) - parent.spacing - timeText.width - parent.spacing
                            spacing: root.f(3)

                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: root._strip(modelData.summary)
                                color: Theme.fg
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: root.f(13)
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: root._strip(modelData.body)
                                color: Theme.muted
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                font.family: Sh.font
                                font.pixelSize: root.f(12)
                            }
                            Row {
                                spacing: root.f(6)
                                visible: row.live && row.live.actions && row.live.actions.length > 0
                                Repeater {
                                    model: row.live && row.live.actions ? row.live.actions : []
                                    delegate: Rectangle {
                                        height: root.f(24)
                                        width: aTxt.implicitWidth + root.f(16)
                                        radius: root.f(7)
                                        color: aArea.containsMouse ? Qt.alpha(Theme.accent, 0.22)
                                                                   : Qt.alpha(Theme.accent, 0.12)
                                        Text {
                                            id: aTxt
                                            anchors.centerIn: parent
                                            text: modelData.text || modelData.identifier
                                            color: Theme.accent
                                            font.family: Sh.font
                                            font.pixelSize: root.f(11)
                                        }
                                        MouseArea {
                                            id: aArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                Notifications.invoke(row.modelData.nid, modelData.identifier)
                                                Notifications.dismiss(row.modelData.nid)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: timeText
                            anchors.verticalCenter: parent.verticalCenter
                            text: root._ago(modelData.time)
                            color: Theme.muted
                            font.family: Sh.font
                            font.pixelSize: root.f(11)
                        }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: root.f(12); top: parent.top; topMargin: root.f(8) }
                        visible: rowArea.containsMouse
                        text: Sh.icX
                        color: Theme.muted
                        font.family: Sh.iconFont
                        font.pixelSize: root.f(13)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -root.f(6)
                            onClicked: Notifications.dismiss(row.modelData.nid)
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (row.live) { Notifications.invoke(row.modelData.nid, "") }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: "No notifications"
                color: Theme.muted
                font.family: Sh.font
                font.pixelSize: root.f(13)
            }
        }
    }
}
