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

    // Keyboard: the grid, with the header buttons one row above it (cur -1, btn picks which).
    readonly property int cols: 4
    property bool atBar: false
    property int btn: 0
    readonly property var bar: [
        () => Capture.shot("region"),
        () => Capture.shot("full"),
        () => { if (!Capture.recording) Sh.closeDeck(); Capture.recToggle() },
        () => { Sh.closeDeck(); Places.openManager(Capture.shotDir) }
    ]
    readonly property bool kb: DeckUi.zone === "center"
    readonly property bool barKb: kb && (atBar || files.length === 0)
    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "captures") return
            const n = cap.files.length
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            if (cap.atBar || n === 0) {
                if (key === Qt.Key_Left)  { if (cap.btn === 0) DeckUi.go("left"); else cap.btn-- }
                if (key === Qt.Key_Right) { if (cap.btn === cap.bar.length - 1) DeckUi.go("right"); else cap.btn++ }
                if (key === Qt.Key_Down && n > 0) cap.atBar = false
                if (enter) cap.bar[cap.btn]()
                return
            }
            const col = cap.cur % cap.cols
            if (key === Qt.Key_Left)  { if (col === 0) DeckUi.go("left"); else cap.cur-- }
            if (key === Qt.Key_Right) { if (col === cap.cols - 1 || cap.cur === n - 1) DeckUi.go("right"); else cap.cur++ }
            if (key === Qt.Key_Up)    { if (cap.cur < cap.cols) cap.atBar = true; else cap.cur -= cap.cols }
            if (key === Qt.Key_Down)  cap.cur = Math.min(n - 1, cap.cur + cap.cols)
            if (enter) cap.open(cap.files[cap.cur])
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
        Button { glyph: Sh.icCamera; label: "Region"; selected: cap.barKb && cap.btn === 0; onClicked: cap.bar[0]() }
        Button { glyph: Sh.icMonitor; label: "Screen"; selected: cap.barKb && cap.btn === 1; onClicked: cap.bar[1]() }
        Button {
            glyph: Sh.icRecord
            label: Capture.recording ? "Stop" : "Record"
            on: Capture.recording
            tint: Theme.error
            selected: cap.barKb && cap.btn === 2
            onClicked: cap.bar[2]()
        }
        Button {
            glyph: Sh.icFolderOpen
            selected: cap.barKb && cap.btn === 3
            onClicked: cap.bar[3]()
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
                readonly property bool sel: cap.kb && !cap.atBar && cap.cur === index
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
            text: "No captures yet"
            color: DeckUi.dim
            font.family: Sh.font
            font.pixelSize: DeckUi.f(13)
        }
    }
}
