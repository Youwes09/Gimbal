import QtQuick
import "root:/modules"

// Workspaces now, the last session and saved setups, each as a strip of workspaces. The
// preview shows whichever workspace has focus; its windows can be dragged onto a Now pill.
// Enter on Now switches workspace; on a saved row it restores that layout.
Item {
    id: sp

    readonly property var saved: (Spaces.last ? [{ kind: "last", name: "Last session", snap: Spaces.last }] : [])
        .concat(Spaces.setups.map(s => ({ kind: "setup", name: s.name, snap: s })))

    // Focus: a row ("head", "now" or "saved" at `ri`) and a workspace within it.
    property string row: "now"
    property int ri: 0
    property int tag: Spaces.active
    property string armed: ""          // setup waiting for a second press…
    property string armAct: ""         // …to "delete" or "replace" it
    property bool naming: false
    property string renaming: ""       // setup whose name is being edited

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

    // Deleting or replacing a setup takes a second press.
    function confirm(name, act) {
        if (sp.armed !== name || sp.armAct !== act) { sp.armed = name; sp.armAct = act; return }
        sp.armed = ""
        if (act === "replace") { Spaces.saveSetup(name); return }
        Spaces.deleteSetup(name)
        Qt.callLater(() => sp.saved.length ? sp.enterRow("saved", Math.min(sp.ri, sp.saved.length - 1)) : sp.enterRow("now"))
    }
    function reorder(name, d) {
        if (Spaces.moveSetup(name, d)) sp.ri = sp.saved.findIndex(s => s.kind === "setup" && s.name === name)
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
    function finishRename(text, save) {
        if (!sp.renaming) return
        if (save) Spaces.renameSetup(sp.renaming, text)
        sp.renaming = ""
        DeckUi.refocus()
    }

    Connections {
        target: DeckUi
        function onNav(key, mods) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "spaces") return
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            const s = sp.row === "saved" && sp.saved[sp.ri] && sp.saved[sp.ri].kind === "setup" ? sp.saved[sp.ri] : null
            if (key === Qt.Key_Return || key === Qt.Key_Enter) { sp.activate(); return }
            if (s && (mods & Qt.ShiftModifier) && (U || D)) { sp.reorder(s.name, U ? -1 : 1); return }
            if (s && (key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X)) { sp.confirm(s.name, "delete"); return }
            if (s && key === Qt.Key_U) { sp.confirm(s.name, "replace"); return }
            if (s && (key === Qt.Key_R || key === Qt.Key_F2)) { sp.renaming = s.name; return }
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
        }
    }

    // A small icon button on a saved row.
    component RowAction: Rectangle {
        id: ra
        property string glyph
        property bool armed: false
        signal clicked()
        width: DeckUi.f(26); height: width
        radius: DeckUi.f(7)
        color: ra.armed ? Qt.alpha(DeckUi.danger, 0.18) : ama.containsMouse ? DeckUi.hover : "transparent"
        Behavior on color { CAnim {} }
        Text {
            anchors.centerIn: parent
            text: ra.glyph
            color: ra.armed ? DeckUi.danger : ama.containsMouse ? DeckUi.text : DeckUi.dim
            font.family: Sh.iconFont
            font.pixelSize: DeckUi.f(13)
        }
        MouseArea {
            id: ama
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ra.clicked()
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
            text: preview.dragging ? "Drop on a workspace" : n + (n === 1 ? " window" : " windows")
            color: preview.dragging ? DeckUi.accent : DeckUi.faint
            font.family: DeckUi.mono
            font.pixelSize: DeckUi.f(11)
        }
        SpacePreview {
            id: preview
            anchors { left: parent.left; right: parent.right; top: peekTitle.bottom; bottom: parent.bottom; margins: DeckUi.f(14); topMargin: DeckUi.f(10) }
            windows: sp.focusTags[sp.tag - 1] || []
            live: sp.row !== "saved"
            dragLayer: sp
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
        acceptsWindows: true
        onHovered: (t) => { if (!preview.dragging) { sp.enterRow("now"); sp.tag = t } }
        onPicked: (t) => { Spaces.view(t); Sh.closeDeck() }
        onWindowDropped: (t, w) => Spaces.moveWindow(w, t)
    }

    Caption {
        id: savedCap
        anchors { left: parent.left; right: parent.right; top: nowStrip.bottom; topMargin: DeckUi.f(20) }
        visible: sp.saved.length > 0 || sp.naming
        text: "Saved"
    }
    Flickable {
        id: savedList
        anchors { left: parent.left; right: parent.right; top: savedCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
        contentHeight: savedCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Behavior on contentY { Anim {} }

        // Keeps the keyboard selection in view.
        function reveal(item) {
            if (!item) return
            if (item.y < contentY) contentY = item.y
            else if (item.y + item.height > contentY + height) contentY = item.y + item.height - height
        }

        Column {
            id: savedCol
            width: savedList.width
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
                    readonly property bool setup: modelData.kind === "setup"
                    readonly property bool sel: sp.kb && sp.row === "saved" && sp.ri === index
                    readonly property bool arm: srow.setup && sp.armed === modelData.name
                    readonly property bool editing: srow.setup && sp.renaming === modelData.name
                    readonly property bool showActions: srow.setup && (srow.sel || rma.containsMouse || srow.arm)
                    onSelChanged: if (sel) savedList.reveal(srow)
                    width: parent.width
                    height: DeckUi.f(34) + DeckUi.f(46) + DeckUi.f(4)
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
                    // Name, age and actions over a full-width strip that lines up with Now.
                    Item {
                        id: head
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: DeckUi.f(12); rightMargin: DeckUi.f(6) }
                        height: DeckUi.f(34)

                        Text {
                            id: nameText
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: Math.min(implicitWidth, head.width * 0.5)
                            visible: !srow.editing
                            elide: Text.ElideRight
                            text: srow.modelData.name
                            color: srow.arm && sp.armAct === "delete" ? DeckUi.danger : DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(12.5)
                            font.weight: Font.Medium
                        }
                        TextInput {
                            id: renameField
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: head.width * 0.5
                            visible: srow.editing
                            clip: true
                            color: DeckUi.text
                            selectionColor: Qt.alpha(DeckUi.accent, 0.4)
                            selectedTextColor: DeckUi.text
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(12.5)
                            font.weight: Font.Medium
                            Keys.onReturnPressed: sp.finishRename(text, true)
                            Keys.onEnterPressed: sp.finishRename(text, true)
                            Keys.onEscapePressed: sp.finishRename(text, false)
                            onActiveFocusChanged: if (!activeFocus && srow.editing) sp.finishRename(text, false)
                            Connections {
                                target: srow
                                function onEditingChanged() {
                                    if (!srow.editing) return
                                    renameField.text = srow.modelData.name
                                    renameField.selectAll()
                                    renameField.forceActiveFocus()
                                }
                            }
                        }
                        Text {
                            anchors { left: srow.editing ? renameField.right : nameText.right; leftMargin: DeckUi.f(10); baseline: nameText.baseline }
                            text: srow.editing ? "Enter to rename"
                                : srow.arm ? (sp.armAct === "delete" ? "Delete again" : "Replace again")
                                : sp._ago(srow.modelData.snap.at)
                            color: srow.arm ? (sp.armAct === "delete" ? DeckUi.danger : DeckUi.accent) : DeckUi.faint
                            font.family: DeckUi.mono
                            font.pixelSize: DeckUi.f(10.5)
                        }

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: DeckUi.f(2)
                            visible: srow.showActions
                            RowAction {
                                glyph: Sh.icPencil
                                onClicked: sp.renaming = srow.modelData.name
                            }
                            RowAction {
                                glyph: Sh.icRefresh
                                armed: srow.arm && sp.armAct === "replace"
                                onClicked: sp.confirm(srow.modelData.name, "replace")
                            }
                            RowAction {
                                glyph: Sh.icTrash
                                armed: srow.arm && sp.armAct === "delete"
                                onClicked: sp.confirm(srow.modelData.name, "delete")
                            }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: DeckUi.f(6); verticalCenter: parent.verticalCenter }
                            visible: !srow.setup && srow.sel
                            text: "Restore"
                            color: DeckUi.accent
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(12)
                            font.weight: Font.Medium
                        }
                    }
                    SpaceStrip {
                        anchors { left: parent.left; right: parent.right; top: head.bottom }
                        tags: Spaces.group(srow.modelData.snap.windows)
                        selected: srow.sel ? sp.tag : 0
                        onHovered: (t) => { sp.enterRow("saved", srow.index); sp.tag = t }
                        onPicked: { sp.enterRow("saved", srow.index); sp.activate() }
                    }
                }
            }
        }
    }
}
