import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "root:/modules"
import "root:/pages/deck"

// The polkit agent: when an app asks for admin rights, a card asks for your password.
// Nothing is on screen (or loaded) until a request comes in.
Scope {
    id: root

    PolkitAgent { id: agent }

    LazyLoader {
        active: agent.isActive

        PanelWindow {
            id: win
            screen: Sh.focusedScreen
            function f(px) { return Sh.sz("polkit", px * DeckUi.scale) }
            readonly property var flow: agent.flow
            property real t: 0
            property bool wrong: false

            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gimbal-polkit"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Component.onCompleted: show.start()
            Anim { id: show; target: win; property: "t"; to: 1; duration: Motion.base }

            function submit() {
                if (!win.flow || !win.flow.isResponseRequired || !field.text.length) return
                win.wrong = false
                win.flow.submit(field.text)
            }
            function cancel() { if (win.flow) win.flow.cancelAuthenticationRequest() }

            Connections {
                target: win.flow
                function onAuthenticationFailed() { win.wrong = true; field.text = ""; field.forceActiveFocus() }
                function onIsResponseRequiredChanged() { if (win.flow.isResponseRequired) field.forceActiveFocus() }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55 * win.t)
                MouseArea { anchors.fill: parent }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (1 - win.t) * win.f(12)
                opacity: win.t
                width: win.f(420)
                height: body.implicitHeight + win.f(40)
                radius: win.f(16)
                color: DeckUi.card
                border.width: 1
                border.color: DeckUi.rim

                Column {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: win.f(20) }
                    spacing: win.f(14)

                    Row {
                        spacing: win.f(12)
                        Rectangle {
                            width: win.f(34); height: width
                            radius: win.f(8)
                            color: DeckUi.well
                            border.width: 1
                            border.color: DeckUi.line
                            Text {
                                anchors.centerIn: parent
                                text: Sh.icLock
                                color: DeckUi.text
                                font.family: Sh.iconFont
                                font.pixelSize: win.f(16)
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: win.f(2)
                            Text {
                                text: "Authentication required"
                                color: DeckUi.text
                                font.family: DeckUi.sans
                                font.pixelSize: win.f(14)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.flow ? win.flow.actionId : ""
                                width: body.width - win.f(46)
                                elide: Text.ElideMiddle
                                color: DeckUi.faint
                                font.family: DeckUi.mono
                                font.pixelSize: win.f(10.5)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: win.flow ? win.flow.message : ""
                        color: DeckUi.dim
                        font.family: DeckUi.sans
                        font.pixelSize: win.f(12)
                        lineHeight: 1.15
                    }

                    Rectangle {
                        width: parent.width
                        height: win.f(40)
                        radius: win.f(8)
                        color: DeckUi.well
                        border.width: 1
                        border.color: win.wrong ? DeckUi.danger : field.activeFocus ? DeckUi.selRim : DeckUi.line
                        Behavior on border.color { CAnim {} }

                        TextInput {
                            id: field
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: win.f(12) }
                            focus: true
                            enabled: !!win.flow && win.flow.isResponseRequired
                            echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            color: DeckUi.text
                            selectionColor: Qt.alpha(DeckUi.accent, 0.4)
                            font.family: DeckUi.mono
                            font.pixelSize: win.f(13)
                            clip: true
                            onTextChanged: if (text.length) win.wrong = false
                            Keys.onReturnPressed: win.submit()
                            Keys.onEnterPressed: win.submit()
                            Keys.onEscapePressed: win.cancel()
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !field.text.length
                                text: {
                                    const p = win.flow ? String(win.flow.inputPrompt).replace(/:\s*$/, "").trim() : ""
                                    return p || "Password"
                                }
                                color: DeckUi.faint
                                font.family: DeckUi.sans
                                font.pixelSize: win.f(12)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: win.f(34)
                        Text {
                            anchors { left: parent.left; right: buttons.left; rightMargin: win.f(12); verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: win.wrong ? "Wrong password" : win.flow ? win.flow.supplementaryMessage : ""
                            color: win.wrong || (win.flow && win.flow.supplementaryIsError) ? DeckUi.danger : DeckUi.faint
                            font.family: DeckUi.sans
                            font.pixelSize: win.f(11.5)
                        }
                        Row {
                            id: buttons
                            anchors.right: parent.right
                            spacing: win.f(8)
                            Button { sz: win.f; label: "Cancel"; onClicked: win.cancel() }
                            Button { sz: win.f; label: "Authenticate"; on: true; onClicked: win.submit() }
                        }
                    }
                }
            }
        }
    }
}
