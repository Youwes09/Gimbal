import QtQuick
import QtQuick.Shapes
import Quickshell
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    readonly property real threshold: 300
    readonly property real edgeZone:  Sh.fs(90)
    readonly property int  disarmMs:  4500

    property real topRaw: 0
    property real botRaw: 0
    property bool dragging: false
    property string armed: ""

    readonly property real topProgress: Math.min(1, topRaw / threshold)
    readonly property real botProgress: Math.min(1, botRaw / threshold)

    readonly property string _zone: (botRaw > 2 || armed === "sleep") ? "bottom"
                                  : (topRaw > 2 || armed === "power") ? "top" : ""
    Binding { target: Sh; property: "powerZone"; value: root._zone }
    Binding { target: Sh; property: "powerPush"; value: root._pull(root.topRaw) - root._pull(root.botRaw) }
    Binding {
        target: Sh; property: "powerDim"
        value: 0.28 * Math.max(root.topProgress, root.botProgress, root.armed !== "" ? 1 : 0)
    }

    function _pull(raw) { return 150 * (1 - Math.exp(-raw / 400)) * 1.15 }

    Behavior on topRaw {
        enabled: !root.dragging
        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
    }
    Behavior on botRaw {
        enabled: !root.dragging
        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
    }

    function _fire(which) {
        root.armed = ""
        root.topRaw = 0
        root.botRaw = 0
        disarm.stop()
        if (which === "power") {
            Quickshell.execDetached(["systemctl", "poweroff"])
            Sh.close()
        } else {
            Sh.beginSuspend()
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }
    function _arm(which) {
        root.armed = which
        if (which === "power") { root.topRaw = threshold; root.botRaw = 0 }
        else                   { root.botRaw = threshold; root.topRaw = 0 }
        disarm.restart()
    }
    function cancel() {
        root.armed = ""
        root.dragging = false
        root.topRaw = 0
        root.botRaw = 0
        disarm.stop()
    }
    function confirm() {
        if (root.armed !== "") _fire(root.armed)
    }
    function key(up) {
        const want = up ? "power" : "sleep"
        if (root.armed === want) _fire(want)
        else _arm(want)
    }

    Timer { id: disarm; interval: root.disarmMs; onTriggered: root.cancel() }
    Connections {
        target: Sh
        function onShownChanged() { if (!Sh.shown) root.cancel() }
    }

    MouseArea {
        anchors.fill: parent
        property real pressX: 0
        property real pressY: 0
        property real grabY: 0
        property string zone: ""

        onPressed: (m) => {
            pressX = m.x; pressY = m.y
            zone = root.armed === "power" ? "top"
                 : root.armed === "sleep" ? "bottom"
                 : m.y <= root.edgeZone ? "top"
                 : m.y >= height - root.edgeZone ? "bottom" : ""
            if (zone === "") return
            root.dragging = true
            grabY = root.armed !== "" ? m.y - root.topRaw + root.botRaw : m.y
        }
        onPositionChanged: (m) => {
            if (zone === "") return
            const delta = m.y - grabY
            if (zone === "top") root.topRaw = Math.max(0, delta)
            else                root.botRaw = Math.max(0, -delta)
        }
        onReleased: (m) => {
            if (zone === "") return
            root.dragging = false
            if (zone === "top") {
                if (root.topProgress >= 1) root._arm("power")
                else { root.topRaw = 0; if (root.armed === "power") root.armed = "" }
            } else {
                if (root.botProgress >= 1) root._arm("sleep")
                else { root.botRaw = 0; if (root.armed === "sleep") root.armed = "" }
            }
            zone = ""
        }
        onClicked: (m) => {
            if (Math.abs(m.x - pressX) > 15 || Math.abs(m.y - pressY) > 15) return
            if (root.armed !== "") root.cancel()
            else Sh.close()
        }
    }

    Timer { id: wheelCool; interval: 450; onTriggered: wheel.cooling = false }
    WheelHandler {
        id: wheel
        acceptedModifiers: Qt.NoModifier
        property bool cooling: false
        onWheel: (ev) => {
            if (wheel.cooling) return
            const dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 3
            const cap = root.threshold + 40
            if (dy > 0) { root.topRaw = Math.min(cap, root.topRaw + dy); root.botRaw = 0 }
            else        { root.botRaw = Math.min(cap, root.botRaw - dy); root.topRaw = 0 }
            if (root.topProgress >= 1) {
                root.armed === "power" ? root._fire("power") : root._arm("power")
                wheel.cooling = true; wheelCool.restart()
            } else if (root.botProgress >= 1) {
                root.armed === "sleep" ? root._fire("sleep") : root._arm("sleep")
                wheel.cooling = true; wheelCool.restart()
            }
        }
    }

    Repeater {
        model: 2

        Item {
            id: ringRoot
            required property int index
            anchors.fill: parent

            readonly property bool   isTop:    index === 0
            readonly property real   progress: isTop ? root.topProgress : root.botProgress
            readonly property real   pull:     root._pull(isTop ? root.topRaw : root.botRaw)
            readonly property string label:    isTop ? "power off?" : "sleep?"
            readonly property bool   isArmed:  root.armed === (isTop ? "power" : "sleep")
            readonly property real   ringSize: Sh.fs(40)
            readonly property color  accent:   Qt.rgba(0.62, 0.92, 0.72, 0.95)

            visible: pull > 0.5 || isArmed

            Item {
                id: ring
                width: ringRoot.ringSize
                height: ringRoot.ringSize
                anchors.horizontalCenter: parent.horizontalCenter
                y: ringRoot.isTop ? -height + ringRoot.pull
                                  : parent.height - ringRoot.pull
                opacity: Math.min(1, ringRoot.pull / 22)

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: ringRoot.isArmed ? ringRoot.accent : Qt.rgba(1, 1, 1, 0.9)
                        strokeWidth: 3
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ring.width / 2
                            centerY: ring.height / 2
                            radiusX: ring.width / 2 - 3
                            radiusY: ring.height / 2 - 3
                            startAngle: -90
                            sweepAngle: 360 * Math.max(0.001, ringRoot.progress)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ringRoot.isTop ? Sh.icPower : Sh.icMoon
                    color: ringRoot.isArmed ? ringRoot.accent : Qt.rgba(1, 1, 1, 0.9)
                    font.family: Sh.iconFont
                    font.pixelSize: Sh.fs(17)
                }

                SequentialAnimation on scale {
                    running: ringRoot.isArmed
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0;  to: 1.12; duration: 640; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.12; to: 1.0;  duration: 640; easing.type: Easing.InOutSine }
                }
            }

            ScrambleText {
                id: promptLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: ringRoot.isTop ? ring.y + ring.height + Sh.fs(14)
                                  : ring.y - promptLabel.height - Sh.fs(14)
                content: ringRoot.label
                gateOnReveal: false
                show: ringRoot.progress >= 0.85 || ringRoot.isArmed
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: Sh.font
                font.pixelSize: Sh.fs(15)
                font.weight: Font.Medium
                font.letterSpacing: 2
                font.capitalization: Font.AllUppercase
                opacity: (ringRoot.progress >= 0.85 || ringRoot.isArmed) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
    }
}
