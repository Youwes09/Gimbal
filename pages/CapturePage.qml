import QtQuick
import QtQuick.Effects
import Quickshell
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    function f(px) { return Sh.fs(px) }

    readonly property color fg:     Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted:  Qt.rgba(1, 1, 1, 0.5)
    readonly property color faint:  Qt.rgba(1, 1, 1, 0.24)
    readonly property color accent: Qt.rgba(0.56, 0.9, 0.66, 0.95)

    readonly property bool has: Capture.activePath.length > 0
    readonly property int browseIdx: Capture.idx >= 0 ? Capture.idx
        : Math.max(0, Capture.list.findIndex(x => x.path === Capture.activePath))
    readonly property int browseTotal: Capture.list.length

    property bool _on: false
    Component.onCompleted: {
        Capture.refreshList()
        Qt.callLater(() => root._on = true)
        shotSlot.setSource(Capture.activePath)
    }
    Connections {
        target: Sh
        function onPageChanged() { if (Sh.page === "capture") Capture.refreshList() }
    }
    Connections {
        target: Capture
        function onActivePathChanged() {
            shotSlot.setSource(Capture.activePath)
            root._specsOn = false
            specsBack.restart()
        }
    }
    property bool _specsOn: true
    Timer { id: specsBack; interval: 90; onTriggered: root._specsOn = true }

    property date now: new Date()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }

    function _ago(ms) {
        const s = Math.max(0, Math.round((root.now.getTime() - ms) / 1000))
        if (s < 5) return "just now"
        if (s < 60) return s + "s ago"
        const m = Math.floor(s / 60)
        if (m < 60) return m + "m ago"
        return Math.floor(m / 60) + "h ago"
    }
    function _size(b) {
        if (b <= 0) return ""
        if (b < 1024) return b + " B"
        if (b < 1048576) return (b / 1024).toFixed(0) + " KB"
        return (b / 1048576).toFixed(1) + " MB"
    }

    function copy()    { Capture.copyImage() }
    function copyAndClose() { Capture.copyImage(); Sh.close() }
    function annotate() { Capture.annotate() }
    function open()    { Capture.open() }
    function reveal()  { Capture.reveal() }
    function discard() { Capture.remove() }
    function prev() { Capture.browse(-1) }
    function next() { Capture.browse(1) }

    Column {
        anchors.centerIn: parent
        spacing: root.f(18)
        opacity: root._on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        scale: root._on ? 1 : 0.98
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        ScrambleText {
            anchors.horizontalCenter: parent.horizontalCenter
            gateOnReveal: false
            show: root._on
            content: "SCREENSHOT"
            color: root.muted
            font.family: Sh.font
            font.pixelSize: root.f(15)
            font.weight: Font.Medium
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real maxW: root.width * 0.62
            readonly property real maxH: root.height * 0.58
            property real ar: 16 / 9
            width: Math.min(frame.maxW, frame.maxH * frame.ar)
            height: Math.min(frame.maxH, frame.maxW / frame.ar)
            Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            radius: root.f(14)
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowBlur: 1.0
                shadowVerticalOffset: root.f(18)
                blurMax: 64
            }

            Item {
                id: shotSlot
                anchors.fill: parent
                anchors.margins: 1
                property bool aFront: true

                function _apply(img) {
                    if (img.status !== Image.Ready) return
                    frame.ar = img.sourceSize.width / img.sourceSize.height
                    shotSlot.aFront = (img === shotA)
                }
                function setSource(path) {
                    const url = path.length ? ("file://" + path) : ""
                    const back = shotSlot.aFront ? shotB : shotA
                    if (back.source === url) return
                    back.source = url
                    if (!url.length) shotSlot._apply(back)
                }

                Image {
                    id: shotA
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                    smooth: true
                    opacity: shotSlot.aFront ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    onStatusChanged: if (status === Image.Ready) shotSlot._apply(shotA)
                }
                Image {
                    id: shotB
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                    smooth: true
                    opacity: shotSlot.aFront ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    onStatusChanged: if (status === Image.Ready) shotSlot._apply(shotB)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.has
                text: "no capture yet"
                color: root.faint
                font.family: Sh.font
                font.pixelSize: root.f(13)
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.f(12)
            visible: root.has
            opacity: root._on && root._specsOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Repeater {
                model: {
                    const out = []
                    if (Capture.shotW > 0) out.push(Capture.shotW + " × " + Capture.shotH)
                    if (Capture.shotBytes > 0) out.push(root._size(Capture.shotBytes))
                    out.push((Capture.shotFmt || "PNG").toUpperCase())
                    out.push(root._ago(Capture.shotAt))
                    return out
                }
                delegate: Row {
                    spacing: root.f(12)
                    ScrambleText {
                        anchors.verticalCenter: parent.verticalCenter
                        delay: 60 + index * 40
                        gateOnReveal: false
                        show: root._on
                        content: modelData
                        color: root.muted
                        font.family: Sh.font
                        font.pixelSize: root.f(13)
                        font.letterSpacing: 1
                    }
                    Text {
                        visible: index < 3
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: root.accent
                        font.family: Sh.font
                        font.pixelSize: root.f(13)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Capture.activePath
                  + (root.browseTotal > 1 ? "   ·   " + (root.browseIdx + 1) + " / " + root.browseTotal : "")
            visible: root.has
            opacity: root._on && root._specsOn ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: root.faint
            font.family: Sh.font
            font.pixelSize: root.f(11)
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.width * 0.55)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        text: root.has ? "←/→ browse · c copy · a annotate · o open · r reveal · del discard · esc close"
                       : "esc to close"
        color: Qt.rgba(1, 1, 1, 0.22)
        font.family: Sh.font
        font.pixelSize: root.f(12)
    }
}
