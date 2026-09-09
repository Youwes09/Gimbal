import QtQuick
import QtMultimedia

Item {
    id: root

    property string source: ""
    property bool playing: true
    readonly property bool ready: player.hasVideo

    VideoOutput {
        id: vout
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: player
        source: root.source.length > 0
            ? (root.source.indexOf("://") >= 0 ? root.source : "file://" + root.source)
            : ""
        loops: MediaPlayer.Infinite
        videoOutput: vout
        audioOutput: AudioOutput { muted: true }
        onErrorOccurred: (err, str) => console.log("[WallpaperVideoPool] error", err, str)
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.playing) player.play()
        }
    }

    function _sync() {
        if (root.source.length > 0 && root.playing) player.play()
        else player.pause()
    }
    onSourceChanged: _sync()
    onPlayingChanged: _sync()
}
