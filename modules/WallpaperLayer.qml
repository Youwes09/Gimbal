import QtQuick
import QtQuick.Effects
import "root:/modules"

Item {
    id: root

    property string path: ""
    property bool blurred: false
    property int fitW: width
    property int fitH: height

    property bool rendering: true

    readonly property bool isVideo: /\.(mp4|webm|mkv|mov)$/i.test(root.path)
    readonly property bool isGif:   /\.gif$/i.test(root.path)

    function _url(p) {
        return p.length === 0 ? "" : (p.indexOf("://") >= 0 ? p : "file://" + p)
    }

    readonly property bool ready:
        root.path.length === 0 ? false
      : root.isVideo ? (video.item ? video.item.ready : false)
      : (still.item ? (still.item.status === Image.Ready) : false)
    property bool everReady: false
    onReadyChanged: if (ready) everReady = true

    Loader {
        id: still
        anchors.fill: parent
        active: root.path.length > 0 && !root.isVideo
        sourceComponent: root.isGif ? gifComp : imgComp
    }
    Component {
        id: imgComp
        Image {
            source: root._url(root.path)
            fillMode: Image.PreserveAspectCrop

            cache: false
            asynchronous: true
            sourceSize.width: root.fitW
            sourceSize.height: root.fitH
            layer.enabled: root.blurred
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, Math.round(root.fitW)),
                                       Math.max(1, Math.round(root.fitH)))
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.5 }
        }
    }
    Component {
        id: gifComp
        AnimatedImage {
            source: root._url(root.path)
            fillMode: Image.PreserveAspectCrop
            cache: true
            playing: true
            layer.enabled: root.blurred
            layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.5 }
        }
    }

    Loader {
        id: video
        anchors.fill: parent
        active: root.isVideo && root.path.length > 0 && root.rendering
        source: "WallpaperVideoPool.qml"

        layer.enabled: root.blurred
        layer.smooth: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.5 }
        onStatusChanged: {
            if (status === Loader.Error)
                console.log("[WallpaperLayer] video pool failed to load — QtMultimedia missing?")
        }
        onLoaded: {
            item.playing = Qt.binding(() => true)
            item.source = Qt.binding(() => root.isVideo ? root.path : "")
        }
    }
}
