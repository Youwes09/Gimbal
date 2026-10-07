import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/modules"
import "root:/pages"

PanelWindow {
    id: root

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

        // Pages are built on open and torn down on close, so they hold no memory while hidden.
        Loader {
            id: wallLoader
            anchors.fill: parent
            active: root.active && Sh.page === "wallpaper"
            sourceComponent: WallpaperCarousel {}
        }
        Loader {
            anchors.fill: parent
            active: root.active && Sh.page === "rest"
            sourceComponent: RestPage {}
        }

        TapHandler {
            enabled: Sh.page === "rest"
            onTapped: Sh.close()
        }
    }

    // Long idle on the rest screen: fade to true black (OLED pixels off). Any input brings it back.
    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: opacity > 0
        opacity: root.active && Sh.page === "rest" && Idle.dark ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1800; easing.type: Easing.InOutSine } }
    }

    Item {
        id: keyCatch
        anchors.fill: parent
        focus: true

        Keys.onPressed: (e) => {
            if (Sh.page === "rest") { Sh.close(); e.accepted = true }
        }
        Keys.onEscapePressed: Sh.close()
        Keys.onLeftPressed:   if (wallLoader.item) wallLoader.item.step(-1)
        Keys.onRightPressed:  if (wallLoader.item) wallLoader.item.step(1)
        Keys.onReturnPressed: if (wallLoader.item) wallLoader.item.apply()
        Keys.onEnterPressed:  if (wallLoader.item) wallLoader.item.apply()
    }
}
