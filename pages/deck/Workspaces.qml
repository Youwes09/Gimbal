import QtQuick
import "root:/modules"

// Workspaces now, the last session and saved setups, each as a strip of workspaces. The
// preview shows whichever workspace has focus. Enter on Now switches to it; on a saved row
// it restores that layout.
Item {
    id: sp

    readonly property var saved: (Spaces.last ? [{ kind: "last", name: "Last session", snap: Spaces.last }] : [])
        .concat(Spaces.setups.map(s => ({ kind: "setup", name: s.name, snap: s })))

    // Focus: a row ("head", "now" or "saved" at `ri`) and a workspace within it.
    property string row: "now"
    property int ri: 0
    property int tag: Spaces.active
    property string armed: ""          // setup waiting for a second Delete
    property bool naming: false

    readonly property bool kb: DeckUi.zone === "center"
    readonly property var focusTags: sp.row === "saved" && sp.saved[sp.ri]
        ? Spaces.group(sp.saved[sp.ri].snap.windows) : Spaces.tags
    function _ago(ms) { const a = Status.ago(ms); return a === "now" ? "just now" : a + " ago" }

    function enterRow(r, i) {
        sp.row = r
        sp.ri = i || 0
        sp.armed = ""
    }
    function stepTag(d) {
        if (sp.tag + d < 1 || sp.tag + d > 9) return false
        sp.tag += d
        return true
    }
    function activate() {
        if (sp.row === "head") { sp.startNaming(); return }
        if (sp.row === "now") { Spaces.view(sp.tag); Sh.closeDeck(); return }
        const s = sp.saved[sp.ri]
        if (!s) return
        Sh.closeDeck()
        Spaces.restore(s.snap)
    }
    function startNaming() {
        sp.naming = true
        nameField.text = "Setup " + (Spaces.setups.length + 1)
        nameField.selectAll()
        nameField.forceActiveFocus()
    }
    function finishNaming(save) {
        const name = nameField.text.trim()
        if (save && name.length) Spaces.saveSetup(name)
        sp.naming = false
        DeckUi.refocus()
    }

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "spaces") return
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            if (key === Qt.Key_Return || key === Qt.Key_Enter) { sp.activate(); return }
            if (sp.row === "head") {
                if (L) DeckUi.go("left")
                if (R) DeckUi.go("right")
                if (D) sp.enterRow("now")
                return
            }
            if (L && !sp.stepTag(-1)) DeckUi.go("left")
            if (R && !sp.stepTag(1)) DeckUi.go("right")
            if (U) {
                if (sp.row === "now") sp.enterRow("head")
                else if (sp.ri === 0) sp.enterRow("now")
                else sp.enterRow("saved", sp.ri - 1)
            }
            if (D) {
                if (sp.row === "now" && sp.saved.length) sp.enterRow("saved", 0)
                else if (sp.row === "saved" && sp.ri < sp.saved.length - 1) sp.enterRow("saved", sp.ri + 1)
            }
            if (sp.row === "saved" && (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X)) {
                const s = sp.saved[sp.ri]
                if (!s || s.kind !== "setup") return
                if (sp.armed !== s.name) { sp.armed = s.name; return }
                Spaces.deleteSetup(s.name)
                sp.armed = ""
                Qt.callLater(() => sp.saved.length ? sp.enterRow("saved", Math.min(sp.ri, sp.saved.length - 1)) : sp.enterRow("now"))
            }
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "Spaces"
        detail: Spaces.clients.length + (Spaces.clients.length === 1 ? " window" : " windows")
        Button {
            glyph: Sh.icSave
            label: "Save setup"
            selected: sp.kb && sp.row === "head"
            onClicked: sp.startNaming()
        }
    }

    // Preview of the focused workspace.
    Rectangle {
        id: peek
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: DeckUi.f(16) }
        height: DeckUi.f(196)
        radius: DeckUi.radius
        color: DeckUi.well
        border.width: 1
        border.color: DeckUi.line

        Text {
            id: peekTitle
            anchors { left: parent.left; top: parent.top; margins: DeckUi.f(14) }
            text: (sp.row === "saved" && sp.saved[sp.ri] ? sp.saved[sp.ri].name + "  ·  " : "") + "Workspace " + sp.tag
            color: DeckUi.text
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(13)
            font.weight: Font.DemiBold
        }
        Text {
            anchors { right: parent.right; baseline: peekTitle.baseline; rightMargin: DeckUi.f(14) }
            readonly property int n: (sp.focusTags[sp.tag - 1] || []).length
            text: n + (n === 1 ? " window" : " windows")
            color: DeckUi.faint
            font.family: DeckUi.mono
            font.pixelSize: DeckUi.f(11)
        }
        SpacePreview {
            anchors { left: parent.left; right: parent.right; top: peekTitle.bottom; bottom: parent.bottom; margins: DeckUi.f(14); topMargin: DeckUi.f(10) }
            windows: sp.focusTags[sp.tag - 1] || []
            live: sp.row !== "saved"
            onOpened: Sh.closeDeck()
        }
    }

    Caption {
        id: nowCap
        anchors { left: parent.left; right: parent.right; top: peek.bottom; topMargin: DeckUi.f(20) }
        text: "Now"
    }
    SpaceStrip {
        id: nowStrip
        anchors { left: parent.left; right: parent.right; top: nowCap.bottom; topMargin: DeckUi.f(8) }
        tags: Spaces.tags
        active: Spaces.active
        selected: sp.kb && sp.row === "now" ? sp.tag : 0
        onHovered: (t) => { sp.enterRow("now"); sp.tag = t }
        onPicked: (t) => { Spaces.view(t); Sh.closeDeck() }
    }

    Caption {
        id: savedCap
        anchors { left: parent.left; right: parent.right; top: nowStrip.bottom; topMargin: DeckUi.f(20) }
        visible: sp.saved.length > 0 || sp.naming
        text: "Saved"
    }
    Column {
        anchors { left: parent.left; right: parent.right; top: savedCap.bottom; topMargin: DeckUi.f(8) }
        spacing: DeckUi.f(4)

        Rectangle {
            width: parent.width
            height: sp.naming ? DeckUi.f(40) : 0
            visible: sp.naming
            radius: DeckUi.innerRadius
            color: DeckUi.sel
            border.width: 1
            border.color: DeckUi.selRim
            TextInput {
                id: nameField
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: DeckUi.f(12) }
                color: DeckUi.text
                selectionColor: Qt.alpha(DeckUi.accent, 0.4)
                selectedTextColor: DeckUi.text
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(12.5)
                clip: true
                Keys.onReturnPressed: sp.finishNaming(true)
                Keys.onEnterPressed: sp.finishNaming(true)
                Keys.onEscapePressed: sp.finishNaming(false)
                onActiveFocusChanged: if (!activeFocus && sp.naming) sp.finishNaming(false)
            }
        }

        Repeater {
            model: sp.saved
            Rectangle {
                id: srow
                required property var modelData
                required property int index
                readonly property bool sel: sp.kb && sp.row === "saved" && sp.ri === index
                readonly property bool arm: sp.armed === modelData.name && modelData.kind === "setup"
                width: parent.width
                height: DeckUi.f(56)
                radius: DeckUi.innerRadius
                color: srow.sel ? DeckUi.sel : rma.containsMouse ? DeckUi.hover : "transparent"
                Behavior on color { CAnim {} }

                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: sp.enterRow("saved", srow.index)
                    onClicked: { sp.enterRow("saved", srow.index); sp.activate() }
                }
                Column {
                    anchors { left: parent.left; leftMargin: DeckUi.f(12); verticalCenter: parent.verticalCenter }
                    width: DeckUi.f(120)
                    spacing: DeckUi.f(2)
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: srow.modelData.name
                        color: srow.arm ? DeckUi.danger : DeckUi.text
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(12.5)
                        font.weight: Font.Medium
                    }
                    Text {
                        text: srow.arm ? "Delete again" : sp._ago(srow.modelData.snap.at)
                        color: srow.arm ? DeckUi.danger : DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(10.5)
                    }
                }
                SpaceStrip {
                    anchors { left: parent.left; right: parent.right; leftMargin: DeckUi.f(144); rightMargin: DeckUi.f(72); verticalCenter: parent.verticalCenter }
                    height: DeckUi.f(42)
                    tags: Spaces.group(srow.modelData.snap.windows)
                    selected: srow.sel ? sp.tag : 0
                    onHovered: (t) => { sp.enterRow("saved", srow.index); sp.tag = t }
                    onPicked: { sp.enterRow("saved", srow.index); sp.activate() }
                }
                Text {
                    anchors { right: parent.right; rightMargin: DeckUi.f(12); verticalCenter: parent.verticalCenter }
                    visible: srow.sel
                    text: srow.modelData.kind === "last" ? "Restore" : "Load"
                    color: DeckUi.accent
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(12)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
