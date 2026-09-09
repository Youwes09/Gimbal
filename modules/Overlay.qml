import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"
import "root:/pages"

PanelWindow {
    id: root

    visible: true
    readonly property bool open: Sh.shown === true

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "gimbal"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: root.open ? null : idleRegion
    Region { id: idleRegion }

    function syncGeom() {
        Sh.screenWidth  = root.screen ? root.screen.width  : root.width
        Sh.screenHeight = root.screen ? root.screen.height : root.height
    }
    onScreenChanged: syncGeom()
    onWidthChanged:  syncGeom()
    onHeightChanged: syncGeom()
    Component.onCompleted: {
        syncGeom()

        Colors.regenerate("")
    }

    property bool active: false
    property real stage: 0
    property real contentFade: 0

    onOpenChanged: {
        if (root.open) {
            wallWarm.warm()
            closeAnim.stop()
            root.active = true
            Sh.reveal = 0
            root.stage = 0
            root.contentFade = 0
            openAnim.start()
            keyCatch.forceActiveFocus()
        } else {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: Sh; property: "reveal"; from: 0; to: 1
            duration: 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.35, 0.3, 0.55, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            target: root; property: "stage"; from: 0; to: 1
            duration: 160; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "contentFade"; from: 0; to: 1
            duration: 420; easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation {
                target: Sh; property: "reveal"; to: 0
                duration: 520
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.45, 0.0, 0.65, 0.7, 1.0, 1.0]
            }
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: root; property: "contentFade"; to: 0
                    duration: 420; easing.type: Easing.InCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 360 }
                NumberAnimation {
                    target: root; property: "stage"; to: 0
                    duration: 160; easing.type: Easing.InCubic
                }
            }
        }
        ScriptAction {
            script: {
                root.active = false
                Sh.reveal = 0
                root.contentFade = 0
                Sh.page = "clock"
            }
        }
    }

    Item {
        id: growMask
        layer.enabled: true
        x: -100000; y: -100000
        width: root.width; height: root.height

        Rectangle {
            antialiasing: true
            x: Sh.originX - Sh.revealDiameter / 2
            y: Sh.originY - Sh.revealDiameter / 2
            width: Sh.revealDiameter
            height: Sh.revealDiameter
            radius: width / 2
            color: "white"
        }
    }

    readonly property int bgBlurMax: 64
    Item {
        id: backdrop
        anchors.fill: parent
        clip: true
        visible: root.active && wallSlide.everReady
        opacity: root.stage

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: growMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.05
        }

        WallSlide {
            id: wallSlide
            anchors.fill: parent
            anchors.margins: -root.bgBlurMax
            blurred: true

            rendering: root.active
            fitW: Math.max(1, Math.round(root.width  / 3))
            fitH: Math.max(1, Math.round(root.height / 3))
            path: Wallpaper.path
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.16)
        }
    }

    Item {
        id: content
        anchors.fill: parent
        visible: root.active
        opacity: root.stage * root.contentFade

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: growMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.05
        }

        TapHandler {
            enabled: Sh.page !== "wallpaper"
            onTapped: Sh.close()
        }

        Loader {
            id: clockLoader
            anchors.fill: parent
            sourceComponent: clockPage
            opacity: Sh.page === "wallpaper" ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate { y: Sh.powerPush }
        }
        Component { id: clockPage; ClockPage {} }

        Loader {
            id: wallLoader
            anchors.fill: parent
            active: Sh.page === "wallpaper" || opacity > 0.01
            sourceComponent: wallpaperPage
            opacity: Sh.page === "wallpaper" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Component { id: wallpaperPage; WallpaperCarousel {} }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Sh.powerDim
        }

        PowerArm { id: powerArm; anchors.fill: parent }
    }

    Connections {
        target: Sh
        function onPageChanged() {
            if (Sh.page === "wallpaper" && powerArm.armed !== "") powerArm.cancel()
        }
    }

    Item {
        id: wallWarm
        opacity: 0
        width: 2; height: 2

        readonly property int warmH: Sh.fs(360)
        property var queue: []
        property int qi: 0

        function warm() {
            const L = Wallpapers.list
            if (!L || L.length === 0) return
            const c = Math.max(0, Wallpapers._idx())
            const order = [0, -1, 1, -2, 2]
            const out = []
            for (const d of order) {
                const w = L[((c + d) % L.length + L.length) % L.length]
                if (!w) continue
                const u = w.video
                    ? (w.poster && w.poster.length > 0
                        ? "file://" + w.poster + "?v=" + Wallpapers.posterRev : "")
                    : "file://" + w.path
                if (u.length > 0 && out.indexOf(u) < 0) out.push(u)
            }
            wallWarm.queue = out
            wallWarm.qi = 0
            wallWarm._pull()
        }
        function _pull() {
            warmImg.source = (qi < queue.length) ? queue[qi] : ""
        }
        Component.onCompleted: warm()
        Connections {
            target: Wallpapers
            function onCurrentChanged()   { wallWarm.warm() }
            function onListChanged()      { wallWarm.warm() }
            function onPosterRevChanged() { wallWarm.warm() }
        }

        Image {
            id: warmImg
            asynchronous: true
            cache: true
            sourceSize.height: wallWarm.warmH
            width: 2; height: 2
            fillMode: Image.PreserveAspectCrop
            onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                    wallWarm.qi++
                    Qt.callLater(wallWarm._pull)
                }
            }
        }
    }

    Item {
        id: keyCatch
        anchors.fill: parent
        focus: true

        readonly property bool wall: Sh.page === "wallpaper"

        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_W) {
                Sh.page = keyCatch.wall ? "clock" : "wallpaper"
                e.accepted = true
            }
        }
        Keys.onEscapePressed: {
            if (keyCatch.wall) { Sh.close(); return }
            if (powerArm.armed !== "") powerArm.cancel(); else Sh.close()
        }
        Keys.onLeftPressed:  if (keyCatch.wall && wallLoader.item) wallLoader.item.step(-1)
        Keys.onRightPressed: if (keyCatch.wall && wallLoader.item) wallLoader.item.step(1)
        Keys.onUpPressed:    if (!keyCatch.wall) powerArm.key(true)
        Keys.onDownPressed:  if (!keyCatch.wall) powerArm.key(false)
        Keys.onReturnPressed: keyCatch.wall ? (wallLoader.item && wallLoader.item.apply()) : powerArm.confirm()
        Keys.onEnterPressed:  keyCatch.wall ? (wallLoader.item && wallLoader.item.apply()) : powerArm.confirm()
    }
}
