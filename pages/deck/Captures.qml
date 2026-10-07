import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/modules"

// Latest screenshots and recordings. ←→↑↓ move · enter open · c copy · del to trash.
Item {
    id: cap

    property var files: []   // [{ path, name, video, mtime }]
    property int cur: 0

    function refresh() { _scan.running = true }
    Component.onCompleted: refresh()
    Connections {
        target: Sh
        function onDeckShownChanged() { if (Sh.deckShown) cap.refresh() }
    }

    property Process _scan: Process {
        command: ["sh", "-c",
            'for d in "$1" "$2"; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f '
            + '\\( -name "*.png" -o -name "*.jpg" -o -name "*.mp4" -o -name "*.webm" \\) -printf "%T@\\t%p\\n"; done '
            + '| sort -rn | head -8',
            "_", Capture.shotDir, Capture.recDir]
        stdout: StdioCollector {
            onStreamFinished: {
                cap.files = this.text.split("\n").filter(l => l.length).map(l => {
                    const i = l.indexOf("\t"), p = l.slice(i + 1)
                    return { path: p, name: p.split("/").pop(), video: /\.(mp4|webm)$/i.test(p),
                             mtime: parseFloat(l.slice(0, i)) * 1000 }
                })
                cap.cur = Math.min(cap.cur, Math.max(0, cap.files.length - 1))
            }
        }
    }

    function open(f)  { if (f) { Sh.closeDeck(); Quickshell.execDetached(["xdg-open", f.path]) } }
    function copy(f)  {
        if (f && !f.video) Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "_", f.path])
    }
    function trash(f) {
        if (!f) return
        Quickshell.execDetached(["gio", "trash", f.path])
        cap.files = cap.files.filter(x => x.path !== f.path)
        cap.cur = Math.min(cap.cur, Math.max(0, cap.files.length - 1))
    }

    readonly property int cols: 4
    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "captures" || cap.files.length === 0) return
            const n = cap.files.length
            if (key === Qt.Key_Left)  cap.cur = Math.max(0, cap.cur - 1)
            if (key === Qt.Key_Right) cap.cur = Math.min(n - 1, cap.cur + 1)
            if (key === Qt.Key_Up)    cap.cur = Math.max(0, cap.cur - cap.cols)
            if (key === Qt.Key_Down)  cap.cur = Math.min(n - 1, cap.cur + cap.cols)
            if (key === Qt.Key_Return || key === Qt.Key_Enter) cap.open(cap.files[cap.cur])
            if (key === Qt.Key_C) cap.copy(cap.files[cap.cur])
            if (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X) cap.trash(cap.files[cap.cur])
        }
    }

    Column {
        id: header
        anchors.left: parent.left
        spacing: DeckUi.f(4)
        Text {
            text: "Captures"
            color: Theme.fg
            font.family: Sh.font
            font.pixelSize: DeckUi.f(24)
            font.weight: Font.DemiBold
        }
        Text {
            text: Capture.recording ? "Recording…" : "Screenshots and recordings, newest first"
            color: Capture.recording ? Theme.error : DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(12)
        }
    }
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: DeckUi.f(8)
        Button { glyph: Sh.icCamera; label: "Region"; onClicked: Capture.shot("region") }
        Button { glyph: Sh.icMonitor; label: "Screen"; onClicked: Capture.shot("full") }
        Button {
            glyph: Sh.icRecord
            label: Capture.recording ? "Stop" : "Record"
            on: Capture.recording
            tint: Theme.error
            onClicked: { if (!Capture.recording) Sh.closeDeck(); Capture.recToggle() }
        }
        Button {
            glyph: Sh.icFolderOpen
            onClicked: { Sh.closeDeck(); Places.openManager(Capture.shotDir) }
        }
    }

    Grid {
        id: grid
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        anchors.topMargin: DeckUi.f(20)
        columns: cap.cols
        spacing: DeckUi.f(12)
        readonly property real cw: (width - spacing * (cap.cols - 1)) / cap.cols
        readonly property real ch: Math.min(cw * 0.625 + DeckUi.f(26), (height - spacing) / 2)

        Repeater {
            model: cap.files
            Item {
                id: th
                required property var modelData
                required property int index
                readonly property bool sel: DeckUi.zone === "center" && cap.cur === index
                width: grid.cw
                height: grid.ch

                ClippingRectangle {
                    id: frame
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: parent.height - DeckUi.f(24)
                    radius: DeckUi.innerRadius
                    color: DeckUi.well
                    Image {
                        anchors.fill: parent
                        visible: !th.modelData.video
                        source: th.modelData.video ? "" : "file://" + th.modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: DeckUi.f(320)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: th.modelData.video
                        text: Sh.icPlay
                        color: DeckUi.dim
                        font.family: Sh.iconFont
                        font.pixelSize: DeckUi.f(22)
                    }
                }
                Rectangle {
                    anchors.fill: frame
                    anchors.margins: -DeckUi.f(3)
                    radius: DeckUi.innerRadius + DeckUi.f(3)
                    color: "transparent"
                    border.width: 2
                    border.color: th.sel ? Theme.accent : thMa.containsMouse ? DeckUi.rim : "transparent"
                }
                Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    elide: Text.ElideMiddle
                    text: th.modelData.name
                    color: th.sel ? Theme.fg : DeckUi.faint
                    font.family: Sh.font
                    font.pixelSize: DeckUi.f(10.5)
                }
                MouseArea {
                    id: thMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { cap.cur = th.index; cap.open(th.modelData) }
                }
            }
        }
    }

    Column {
        anchors.centerIn: grid
        visible: cap.files.length === 0
        spacing: DeckUi.f(8)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Sh.icImages
            color: DeckUi.faint
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(28)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No captures yet. Press s for a screenshot."
            color: DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(13)
        }
    }
}
