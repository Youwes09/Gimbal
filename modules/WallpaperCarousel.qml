import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/modules"

Item {
    id: root
    anchors.fill: parent

    readonly property var walls: Wallpapers.list

    property int stepCount: 0
    property real pos: 0
    property bool _touched: false
    Behavior on pos {
        id: posBehavior
        NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
    }

    readonly property int sel: walls.length > 0
        ? ((stepCount % walls.length) + walls.length) % walls.length : -1
    readonly property var centeredWall: root.sel >= 0 ? root.walls[root.sel] : null

    readonly property int barW: Sh.fs(264)
    readonly property int barH: Sh.fs(496)

    readonly property int tileTexH: Sh.fs(360)
    readonly property int slotSpacing: Sh.fs(300)
    readonly property real parallaxPx: Sh.fs(82)
    readonly property real edgeFloor: 0.7
    readonly property real edgeRate: 0.07
    readonly property real edgeBreak: (1 - edgeFloor) / edgeRate
    readonly property real edgeClampedStep: slotSpacing - barW * (1 - edgeFloor)
    function edgeOffset(m) {
        if (m <= edgeBreak)
            return slotSpacing * m - (barW * edgeRate / 2) * m * m
        const atBreak = slotSpacing * edgeBreak - (barW * edgeRate / 2) * edgeBreak * edgeBreak
        return atBreak + edgeClampedStep * (m - edgeBreak)
    }
    readonly property int halfVisible: 2
    readonly property int span: halfVisible + 2
    readonly property int totalSlots: 2 * span + 1

    function step(dir) {
        if (root.walls.length === 0) return
        root._touched = true
        root.stepCount += dir
        root.pos = root.stepCount
    }

    function apply() {
        if (root.centeredWall && root.centeredWall.path !== Wallpapers.current)
            Wallpapers.apply(root.centeredWall.path)
        applyPulse.restart()
        Sh.close()
    }
    function _resync() {
        const i = Wallpapers._idx()
        root._touched = false
        root.stepCount = i >= 0 ? i : 0
        posBehavior.enabled = false
        root.pos = root.stepCount
        posBehavior.enabled = true
    }
    // Created fresh each time the overlay opens.
    Component.onCompleted: {
        Wallpapers.rescan()
        root._resync()
        enterAnim.restart()
    }
    Connections {
        target: Wallpapers
        function onListChanged()    { if (!root._touched) root._resync() }
        function onCurrentChanged() { if (!root._touched) root._resync() }
    }

    property real applyFlash: 0
    NumberAnimation {
        id: applyPulse
        target: root; property: "applyFlash"; from: 1; to: 0
        duration: 520; easing.type: Easing.OutCubic
    }

    Item {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Sh.fs(28)
        width: 2 * root.edgeOffset(root.halfVisible) + root.barW
        height: root.barH

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: strip; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: strip; property: "scale"; from: 0.92; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            NumberAnimation {
                target: strip; property: "anchors.verticalCenterOffset"
                from: -Sh.fs(28) + Sh.fs(34); to: -Sh.fs(28)
                duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        Repeater {
            model: root.totalSlots

            Item {
                id: cell
                required property int index
                property int absStep: index - root.span
                readonly property real rank: absStep - root.pos
                readonly property int wallIndex: root.walls.length > 0
                    ? ((absStep % root.walls.length) + root.walls.length) % root.walls.length : -1
                readonly property var wall: cell.wallIndex >= 0 ? root.walls[cell.wallIndex] : null
                readonly property real selFade: Math.max(0, 1 - Math.abs(rank) * 2)
                readonly property bool centerish: Math.abs(rank) < 1

                function _rebalance() {
                    let s = cell.absStep
                    while (s - root.pos > root.span + 1) s -= root.totalSlots
                    while (s - root.pos < -(root.span + 1)) s += root.totalSlots
                    if (s !== cell.absStep) cell.absStep = s
                }
                Connections {
                    target: root
                    function onPosChanged() { Qt.callLater(cell._rebalance) }

                    function onWallsChanged() {
                        cell.absStep = cell.index - root.span + Math.round(root.pos)
                        Qt.callLater(cell._rebalance)
                    }
                }

                visible: cell.wall !== null
                width: root.barW
                height: root.barH
                y: (parent.height - height) / 2
                x: parent.width / 2 - width / 2 + Math.sign(rank) * root.edgeOffset(Math.abs(rank))
                z: Math.round(-Math.abs(rank) * 100)
                scale: Math.max(root.edgeFloor, 1 - Math.abs(rank) * root.edgeRate)
                opacity: Math.max(0, Math.min(1, root.halfVisible + 1 - Math.abs(rank)))

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Sh.fs(5)
                    radius: Sh.fs(18)
                    color: "transparent"
                    border.width: 3
                    border.color: Qt.alpha(Theme.accent, 0.35 + 0.4 * root.applyFlash * cell.selFade)
                    opacity: cell.selFade
                }

                ClippingRectangle {
                    id: frame
                    anchors.fill: parent
                    radius: Sh.fs(13)
                    color: Qt.alpha(Theme.accent, 0.08 + 0.08 * cell.selFade)

                    readonly property real wide: root.barW
                        + (root.parallaxPx * (root.halfVisible + 1) + Sh.fs(20)) * 2

                    Image {
                        width: frame.wide
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width - width) / 2 - cell.rank * root.parallaxPx
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        retainWhileLoading: true
                        sourceSize.height: root.tileTexH
                        source: {
                            const w = cell.wall
                            if (!w) return ""
                            if (w.video) return w.poster.length > 0
                                ? "file://" + w.poster + "?v=" + Wallpapers.posterRev : ""
                            if (w.wide && w.wide.length > 0)
                                return "file://" + w.wide + "?v=" + Wallpapers.wideRev
                            return "file://" + w.path
                        }
                    }

                    AnimatedImage {
                        readonly property bool live: cell.centerish && cell.wall && cell.wall.gif
                        width: frame.wide
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width - width) / 2 - cell.rank * root.parallaxPx
                        visible: live
                        playing: live
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.height: root.tileTexH
                        source: live ? "file://" + cell.wall.path : ""
                    }

                    Loader {
                        id: vid
                        readonly property bool live: cell.centerish && cell.wall && cell.wall.video
                        active: live
                        width: frame.wide
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width - width) / 2 - cell.rank * root.parallaxPx
                        visible: live && item && item.ready
                        source: "WallpaperVideoPool.qml"
                        onLoaded: {
                            item.source = Qt.binding(() => vid.live ? cell.wall.path : "")
                            item.playing = Qt.binding(() => vid.live)
                        }
                    }
                }

                Rectangle {
                    anchors { left: parent.left; top: parent.top; margins: Sh.fs(8) }
                    visible: cell.wall && cell.wall.path === Wallpapers.current && cell.selFade > 0.5
                    width: Sh.fs(22); height: Sh.fs(22)
                    radius: width / 2
                    color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: Sh.icCorner
                        color: Theme.bg
                        font.family: Sh.iconFont
                        font.pixelSize: Sh.fs(12)
                    }
                }
            }
        }
    }

    ScrambleText {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: strip.bottom
        anchors.topMargin: Sh.fs(26)
        gateOnReveal: false
        show: true
        content: root.centeredWall ? root.centeredWall.name
               : (Wallpapers.list.length === 0 ? "no wallpapers found" : "")
        color: Theme.fg
        font.family: Sh.font
        font.pixelSize: Sh.fs(16)
        font.weight: Font.Medium
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: caption.bottom
        anchors.topMargin: Sh.fs(8)
        visible: Wallpapers.list.length > 0
        textFormat: Text.StyledText
        text: {
            const applied = root.centeredWall && root.centeredWall.path === Wallpapers.current
            const a = "<font color='" + Theme.accent + "'>&middot;</font>"
            return (applied ? "current wallpaper" : "← → cycle") + "   " + a
                 + "   enter apply   " + a + "   esc close"
        }
        color: Theme.muted
        font.family: Sh.font
        font.pixelSize: Sh.fs(11)
    }
}
