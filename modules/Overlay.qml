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
    property bool _fastRun: false

    onOpenChanged: {
        if (root.open) {
            closeAnim.stop()
            root.active = true
            root._fastRun = Sh.fastOpen
            Sh.fastOpen = false
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
            duration: root._fastRun ? 170 : 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.35, 0.3, 0.55, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            target: root; property: "stage"; from: 0; to: 1
            duration: root._fastRun ? 70 : 160; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "contentFade"; from: 0; to: 1
            duration: root._fastRun ? 130 : 420; easing.type: Easing.OutCubic
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
            enabled: Sh.page === "clock" || Sh.page === "suspend"
            onTapped: {
                if (Sh.page === "suspend") {
                    if (suspendLoader.item) suspendLoader.item.tryDismiss()
                    return
                }
                Sh.close()
            }
        }

        Loader {
            id: clockLoader
            anchors.fill: parent
            sourceComponent: clockPage
            opacity: Sh.page === "clock" ? 1 : 0
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

        Loader {
            id: notifLoader
            anchors.fill: parent
            active: Sh.page === "notifications" || opacity > 0.01
            sourceComponent: notifPage
            opacity: Sh.page === "notifications" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Component { id: notifPage; NotificationsPage {} }

        Loader {
            id: suspendLoader
            anchors.fill: parent
            active: Sh.page === "suspend" || opacity > 0.01
            sourceComponent: suspendPage
            opacity: Sh.page === "suspend" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Component { id: suspendPage; SuspendScreen {} }

        Loader {
            id: captureLoader
            anchors.fill: parent
            active: Sh.page === "capture" || opacity > 0.01
            sourceComponent: capturePage
            opacity: Sh.page === "capture" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Component { id: capturePage; CapturePage {} }

        Loader {
            id: networkLoader
            anchors.fill: parent
            active: Sh.page === "network" || opacity > 0.01
            sourceComponent: networkPage
            opacity: Sh.page === "network" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Component { id: networkPage; NetworkPage {} }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Sh.powerDim
        }

        PowerArm { id: powerArm; anchors.fill: parent; enabled: Sh.page === "clock" }
    }

    Connections {
        target: Sh
        function onPageChanged() {
            if (Sh.page !== "clock" && powerArm.armed !== "") powerArm.cancel()
        }
    }

    Item {
        id: keyCatch
        anchors.fill: parent
        focus: true

        Connections {
            target: Sh
            function onReclaimFocus() { keyCatch.forceActiveFocus() }
        }

        readonly property bool wall: Sh.page === "wallpaper"
        readonly property bool notif: Sh.page === "notifications"
        readonly property bool home: Sh.page === "clock"
        readonly property bool cap: Sh.page === "capture"
        readonly property bool net: Sh.page === "network"

        Keys.onPressed: (e) => {
            if (Sh.page === "suspend") {
                if (suspendLoader.item) suspendLoader.item.tryDismiss()
                e.accepted = true
                return
            }
            if (keyCatch.cap && captureLoader.item) {
                const it = captureLoader.item
                if (e.key === Qt.Key_C) { it.copy(); e.accepted = true; return }
                if (e.key === Qt.Key_A) { it.annotate(); e.accepted = true; return }
                if (e.key === Qt.Key_O) { it.open(); e.accepted = true; return }
                if (e.key === Qt.Key_R) { it.reveal(); e.accepted = true; return }
                if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace || e.key === Qt.Key_X) {
                    it.discard(); e.accepted = true; return
                }
            }
            if (e.key === Qt.Key_W) {
                Sh.page = keyCatch.wall ? "clock" : "wallpaper"
                e.accepted = true
            } else if (e.key === Qt.Key_N) {
                Sh.page = keyCatch.notif ? "clock" : "notifications"
                e.accepted = true
            } else if (e.key === Qt.Key_S) {
                Sh.page = keyCatch.cap ? "clock" : "capture"
                e.accepted = true
            } else if (e.key === Qt.Key_B) {
                Sh.page = keyCatch.net ? "clock" : "network"
                e.accepted = true
            } else if (keyCatch.notif && e.key === Qt.Key_D) {
                Notifications.toggleDnd()
                e.accepted = true
            } else if (keyCatch.notif && e.key === Qt.Key_C) {
                Notifications.clearAll()
                e.accepted = true
            } else if (keyCatch.notif && notifLoader.item
                       && (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace || e.key === Qt.Key_X)) {
                notifLoader.item.dropSel()
                e.accepted = true
            }
        }
        Keys.onEscapePressed: {
            if (Sh.page === "suspend") {
                if (suspendLoader.item) suspendLoader.item.tryDismiss()
                return
            }
            if (!keyCatch.home) { Sh.close(); return }
            if (powerArm.armed !== "") powerArm.cancel(); else Sh.close()
        }
        Keys.onLeftPressed: {
            if (keyCatch.wall && wallLoader.item) wallLoader.item.step(-1)
            else if (keyCatch.cap) Capture.browse(-1)
        }
        Keys.onRightPressed: {
            if (keyCatch.wall && wallLoader.item) wallLoader.item.step(1)
            else if (keyCatch.cap) Capture.browse(1)
        }
        Keys.onUpPressed: {
            if (keyCatch.home) powerArm.key(true)
            else if (keyCatch.notif && notifLoader.item) notifLoader.item.moveSel(-1)
        }
        Keys.onDownPressed: {
            if (keyCatch.home) powerArm.key(false)
            else if (keyCatch.notif && notifLoader.item) notifLoader.item.moveSel(1)
        }
        Keys.onReturnPressed: {
            if (keyCatch.wall && wallLoader.item) wallLoader.item.apply()
            else if (keyCatch.notif && notifLoader.item) notifLoader.item.actSel()
            else if (keyCatch.cap && captureLoader.item) captureLoader.item.copyAndClose()
            else if (keyCatch.home) powerArm.confirm()
        }
        Keys.onEnterPressed: {
            if (keyCatch.wall && wallLoader.item) wallLoader.item.apply()
            else if (keyCatch.notif && notifLoader.item) notifLoader.item.actSel()
            else if (keyCatch.cap && captureLoader.item) captureLoader.item.copyAndClose()
            else if (keyCatch.home) powerArm.confirm()
        }
    }
}
