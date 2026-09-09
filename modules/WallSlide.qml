import QtQuick
import "root:/modules"

Item {
    id: root

    property string path: ""
    property bool blurred: false
    property int fitW: width
    property int fitH: height
    property int fadeMs: 320
    property bool rendering: true

    readonly property bool everReady: layerA.everReady || layerB.everReady

    property int residentIdx: -1
    property int fadingIdx: -1
    property real fade: 0
    readonly property Item _res:   residentIdx === 0 ? layerA : layerB
    readonly property Item _spare: residentIdx === 0 ? layerB : layerA
    property string _queued: ""

    onPathChanged: root._apply(root.path)
    function _apply(p) {
        if (p.length === 0) return
        if (root.residentIdx < 0) { layerA.path = p; root.residentIdx = 0; return }
        if (p === root._res.path) return
        if (root.fadingIdx >= 0) { root._queued = p; return }
        root._spare.path = p
    }
    function _spareReady() {
        if (root.fadingIdx >= 0 || root.residentIdx < 0) return
        if (root._spare.path.length > 0 && root._spare.path !== root._res.path && root._spare.ready) {
            root.fadingIdx = (root.residentIdx === 0) ? 1 : 0
            root.fade = 0
            fadeAnim.restart()
        }
    }

    NumberAnimation {
        id: fadeAnim
        target: root; property: "fade"; from: 0; to: 1
        duration: root.fadeMs; easing.type: Easing.InOutQuad
        onFinished: {
            root.residentIdx = root.fadingIdx
            root.fadingIdx = -1
            root.fade = 0

            const parked = root._spare
            if (root._queued.length > 0 && root._queued !== root._res.path) {
                const q = root._queued; root._queued = ""
                Qt.callLater(() => root._apply(q))
            } else {
                root._queued = ""
                parked.path = ""
            }
        }
    }

    WallpaperLayer {
        id: layerA
        anchors.fill: parent
        blurred: root.blurred
        rendering: root.rendering
        fitW: root.fitW; fitH: root.fitH
        readonly property bool fading: root.fadingIdx === 0
        z: fading ? 2 : 0
        opacity: root.residentIdx === 0 ? 1 : (fading ? root.fade : 0)
        onReadyChanged: root._spareReady()
    }
    WallpaperLayer {
        id: layerB
        anchors.fill: parent
        blurred: root.blurred
        rendering: root.rendering
        fitW: root.fitW; fitH: root.fitH
        readonly property bool fading: root.fadingIdx === 1
        z: fading ? 2 : 0
        opacity: root.residentIdx === 1 ? 1 : (fading ? root.fade : 0)
        onReadyChanged: root._spareReady()
    }
}
