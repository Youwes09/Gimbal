import QtQuick
import Quickshell
import "root:/modules"

// One notification, in the deck's list-row style: a bare app icon, summary over
// body, app · age in mono on the right. Nothing drawn at rest.
Rectangle {
    id: nr
    property var rec: null
    property bool compact: false
    property bool selected: false
    signal clicked()

    implicitHeight: nr.compact ? DeckUi.f(48) : DeckUi.f(64)
    radius: DeckUi.innerRadius
    color: nr.selected ? DeckUi.sel : ma.containsMouse ? DeckUi.hover : "transparent"
    border.width: 1
    border.color: nr.selected ? DeckUi.selRim : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    readonly property bool crit: nr.rec && nr.rec.urgency === "critical"

    function _strip(s) {
        return String(s || "").replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&#39;|&apos;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim()
    }
    function _icon(s) {
        if (!s) return ""
        return (s.indexOf("/") === 0 || s.indexOf("://") >= 0) ? s : Quickshell.iconPath(s, true)
    }
    function _ago(ms) {
        const s = Math.max(0, Math.floor((Date.now() - ms) / 1000))
        if (s < 45) return "now"
        if (s < 3600) return Math.round(s / 60) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }

    Rectangle {
        visible: nr.crit
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: DeckUi.f(10) }
        width: 2
        radius: 1
        color: DeckUi.danger
    }

    Item {
        id: ic
        anchors.left: parent.left
        anchors.leftMargin: DeckUi.f(12)
        anchors.verticalCenter: parent.verticalCenter
        width: nr.compact ? DeckUi.f(20) : DeckUi.f(24); height: width
        AppIcon {
            anchors.fill: parent
            fallbackColor: DeckUi.dim
            // Live notification images (image://qsimage) die with the notification; use the app icon then.
            icon: nr.rec ? nr._icon((/^image:\/\/qsimage/.test(nr.rec.image) ? "" : nr.rec.image)
                                    || nr.rec.appIcon || nr.rec.desktopEntry) : ""
            fallbackGlyph: Sh.icBell
        }
    }

    Column {
        anchors.left: ic.right
        anchors.leftMargin: DeckUi.f(12)
        anchors.right: parent.right
        anchors.rightMargin: DeckUi.f(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: DeckUi.f(2)

        Item {
            width: parent.width
            height: sum.implicitHeight
            Text {
                id: sum
                anchors.left: parent.left
                anchors.right: age.left
                anchors.rightMargin: DeckUi.f(8)
                elide: Text.ElideRight
                text: nr.rec ? nr._strip(nr.rec.summary) || nr.rec.app : ""
                color: DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12.5)
                font.weight: Font.DemiBold
            }
            Text {
                id: age
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: nr.rec ? nr.rec.app + "  ·  " + nr._ago(nr.rec.time) : ""
                color: DeckUi.faint
                font.family: DeckUi.mono
                font.pixelSize: DeckUi.f(10.5)
            }
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: nr.rec ? nr._strip(nr.rec.body) : ""
            elide: Text.ElideRight
            wrapMode: nr.compact ? Text.NoWrap : Text.WordWrap
            maximumLineCount: nr.compact ? 1 : 2
            color: DeckUi.dim
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(11.5)
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nr.clicked()
    }
}
