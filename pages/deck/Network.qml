import QtQuick
import Quickshell.Networking
import Quickshell.Bluetooth
import "root:/modules"

// The link you're on and what's moving over it, what you've used per day and per network,
// then Wi-Fi networks and Bluetooth devices side by side. Enter connects or disconnects; a
// secured network asks for its password inline. Delete twice forgets a network or device.
Item {
    id: np

    Binding { target: Net; property: "live"; value: Sh.deckShown && DeckUi.section === "network" }
    // Wi-Fi rescans while the page is up; Bluetooth discovery only on request (it's noisier).
    Binding { target: Net.wifi; property: "scannerEnabled"; value: Net.live; when: !!Net.wifi }
    Component.onDestruction: Net.discover(false)

    // Keyboard: "head" (header buttons), "usage" (days), "wifi" or "bt" lists.
    property string row: "head"
    property int btn: 0
    property int day: 6                // 0..6, oldest to today
    property int wi: 0
    property int bi: 0
    property string armed: ""          // network or device waiting for a second Delete
    property string asking: ""         // network whose password is being typed
    property var failed: ({})          // network name → true after a failed attempt
    readonly property bool kb: DeckUi.zone === "center"
    readonly property bool scanning: !!Net.adapter && Net.adapter.discovering

    function actWifi(n) {
        if (!n) return
        if (n.connected) { n.disconnect(); return }
        if (n.known || !Net.secured(n)) { np._clearFail(n.name); n.connect(); return }
        np.asking = n.name
    }
    function submit(n, psk) {
        np.asking = ""
        DeckUi.refocus()
        if (!n || !psk) return
        np._clearFail(n.name)
        n.connectWithPsk(psk)
    }
    function _clearFail(name) { const f = Object.assign({}, np.failed); delete f[name]; np.failed = f }
    function actBt(d) {
        if (!d) return
        if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { d.trusted = true; d.pair() }
    }
    function forget(key, fn) {
        if (np.armed !== key) { np.armed = key; return }
        np.armed = ""
        fn()
    }
    // Turning Wi-Fi or Bluetooth off takes a second press within a few seconds; on is immediate.
    property string offArmed: ""
    Timer { id: offDisarm; interval: 3000; onTriggered: np.offArmed = "" }
    function toggleRadio(which) {
        const on = which === "wifi" ? Net.wifiOn : Net.btOn
        const set = v => which === "wifi" ? Net.setWifi(v) : Net.setBt(v)
        if (!on) { np.offArmed = ""; set(true); return }
        if (np.offArmed !== which) { np.offArmed = which; offDisarm.restart(); return }
        np.offArmed = ""
        set(false)
    }
    function toggleScan() { Net.discover(!np.scanning) }
    Timer { id: scanStop; interval: 30000; onTriggered: Net.discover(false) }
    onScanningChanged: if (scanning) scanStop.restart()

    Connections {
        target: DeckUi
        function onNav(key) {
            if (DeckUi.zone !== "center" || DeckUi.section !== "network") return
            const L = key === Qt.Key_Left, R = key === Qt.Key_Right, U = key === Qt.Key_Up, D = key === Qt.Key_Down
            const enter = key === Qt.Key_Return || key === Qt.Key_Enter
            const del = key === Qt.Key_Delete || key === Qt.Key_Backspace || key === Qt.Key_X
            const nW = wifiList.count, nB = btList.count
            if (U || D || L || R) { np.armed = ""; np.offArmed = "" }
            if (np.row === "head") {
                if (L) { if (np.btn === 0) DeckUi.go("left"); else np.btn-- }
                if (R) { if (np.btn === 2) DeckUi.go("right"); else np.btn++ }
                if (D) np.row = "usage"
                if (enter) [() => np.toggleRadio("wifi"), () => np.toggleRadio("bt"), np.toggleScan][np.btn]()
                return
            }
            if (np.row === "usage") {
                if (L) { if (np.day === 0) DeckUi.go("left"); else np.day-- }
                if (R) { if (np.day === 6) DeckUi.go("right"); else np.day++ }
                if (U) np.row = "head"
                if (D) np.row = nW ? "wifi" : nB ? "bt" : "usage"
                if (enter) np.day = 6
                return
            }
            if (np.row === "wifi") {
                np.wi = Math.min(np.wi, Math.max(0, nW - 1))
                if (L) DeckUi.go("left")
                if (R) { if (nB) { np.row = "bt"; np.bi = Math.min(np.bi, nB - 1) } else DeckUi.go("right") }
                if (U) { if (np.wi === 0) np.row = "usage"; else np.wi-- }
                if (D) np.wi = Math.min(nW - 1, np.wi + 1)
                const n = Net.networks[np.wi]
                if (enter) np.actWifi(n)
                if (del && n && n.known) np.forget("w:" + n.name, () => n.forget())
                return
            }
            np.bi = Math.min(np.bi, Math.max(0, nB - 1))
            if (L) { if (nW) { np.row = "wifi"; np.wi = Math.min(np.wi, nW - 1) } else DeckUi.go("left") }
            if (R) DeckUi.go("right")
            if (U) { if (np.bi === 0) np.row = "usage"; else np.bi-- }
            if (D) np.bi = Math.min(nB - 1, np.bi + 1)
            const d = Net.devices[np.bi]
            if (enter) np.actBt(d)
            if (del && d && d.paired) np.forget("b:" + d.address, () => d.forget())
        }
    }

    PageHeader {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        title: "Network"
        detail: Net.iface || (Net.wifiOn ? "Not connected" : "Wi-Fi off")
        Button {
            glyph: Net.wifiOn ? Sh.icWifi : Sh.icWifiOff
            label: np.offArmed === "wifi" ? "Turn off?" : "Wi-Fi"
            on: Net.wifiOn
            danger: np.offArmed === "wifi"
            selected: np.kb && np.row === "head" && np.btn === 0
            onClicked: np.toggleRadio("wifi")
        }
        Button {
            glyph: Net.btOn ? Sh.icBluetooth : Sh.icBluetoothOff
            label: np.offArmed === "bt" ? "Turn off?" : "Bluetooth"
            on: Net.btOn
            danger: np.offArmed === "bt"
            selected: np.kb && np.row === "head" && np.btn === 1
            onClicked: np.toggleRadio("bt")
        }
        Button {
            glyph: Sh.icRadar
            label: np.scanning ? "Scanning" : "Scan"
            on: np.scanning
            selected: np.kb && np.row === "head" && np.btn === 2
            onClicked: np.toggleScan()
        }
    }

    // A boxed section: drawn behind its content, padded out by `pad`.
    component Panel: Rectangle {
        property Item around
        readonly property real pad: DeckUi.f(14)
        x: around.x - pad; y: around.y - pad
        width: around.width + pad * 2; height: around.height + pad * 2
        radius: DeckUi.radius
        color: DeckUi.well
        border.width: 1
        border.color: DeckUi.line
    }
    component Stat: Column {
        property string label
        property string value
        spacing: DeckUi.f(1)
        Text { text: parent.label; color: DeckUi.faint; font.family: DeckUi.sans; font.pixelSize: DeckUi.f(10.5) }
        Text { text: parent.value; color: DeckUi.dim; font.family: DeckUi.mono; font.pixelSize: DeckUi.f(11.5) }
    }

    // Link: what you're connected through, and live throughput.
    Item {
        id: link
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: DeckUi.f(30); leftMargin: DeckUi.f(14); rightMargin: DeckUi.f(14) }
        height: DeckUi.f(138)

        Column {
            id: spec
            anchors { left: parent.left; top: parent.top }
            width: parent.width * 0.36
            Text {
                width: parent.width
                height: DeckUi.f(28)
                elide: Text.ElideRight
                text: Net.current ? Net.current.name : Net.wifiOn ? "Offline" : "Wi-Fi off"
                color: Net.current ? DeckUi.text : DeckUi.dim
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(17)
                font.weight: Font.DemiBold
            }
            Spec { label: "Signal"; value: Net.current ? Math.round(Net.current.signalStrength * 100) + "%" : "" }
            Spec {
                label: "Link"
                value: Net.current ? [Net.wlan.band, Net.wlan.channel ? "ch " + Net.wlan.channel : "", Net.wlan.rate]
                    .filter(s => s).join(" · ") : ""
            }
            Spec { label: "Address"; value: Net.address }
            Spec { label: "Gateway"; value: Net.gateway }
            Spec {
                label: "Internet"
                readonly property var c: Networking.connectivity
                value: c === NetworkConnectivity.Full ? "Online" : c === NetworkConnectivity.Portal ? "Sign-in page"
                     : c === NetworkConnectivity.Limited ? "Limited" : c === NetworkConnectivity.None ? "Offline" : ""
                valueColor: c === NetworkConnectivity.Full ? DeckUi.good : DeckUi.danger
            }
            Spec {
                label: "Tailscale"
                value: Net.tailscale + (Net.tailPeers ? " · " + Net.tailPeers + " online" : "")
            }
        }

        Item {
            id: live
            anchors { left: spec.right; leftMargin: DeckUi.f(28); right: parent.right; top: parent.top; bottom: parent.bottom }
            readonly property var rx: Net.rxHist
            readonly property var tx: Net.txHist
            function avg(h) { return h.length ? h.reduce((a, b) => a + b, 0) / h.length : 0 }
            function max(h) { return h.length ? Math.max(...h) : 0 }

            Row {
                id: rates
                height: DeckUi.f(28)
                spacing: DeckUi.f(18)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓ " + Net.rate(Net.rxRate)
                    color: DeckUi.text
                    font.family: DeckUi.mono
                    font.pixelSize: DeckUi.f(15)
                    font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑ " + Net.rate(Net.txRate)
                    color: DeckUi.dim
                    font.family: DeckUi.mono
                    font.pixelSize: DeckUi.f(15)
                    font.weight: Font.Medium
                }
            }
            Row {
                id: stats
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                spacing: DeckUi.f(22)
                Stat { label: "Avg ↓"; value: Net.rate(live.avg(live.rx)) }
                Stat { label: "Peak ↓"; value: Net.rate(live.max(live.rx)) }
                Stat { label: "Avg ↑"; value: Net.rate(live.avg(live.tx)) }
                Stat { label: "Peak ↑"; value: Net.rate(live.max(live.tx)) }
            }
            Sparkline {
                id: graph
                anchors { left: parent.left; right: parent.right; top: rates.bottom; bottom: stats.top; topMargin: DeckUi.f(4); bottomMargin: DeckUi.f(10) }
                a: live.rx
                b: live.tx
                span: Net.window
            }
            Rectangle {
                anchors { left: graph.left; right: graph.right; bottom: graph.bottom }
                height: 1
                color: DeckUi.line
            }
        }
    }

    Panel { around: link; z: -1 }

    // Usage: a day's total and its split by network, next to the last seven days.
    Item {
        id: usage
        anchors { left: parent.left; right: parent.right; top: link.bottom; topMargin: DeckUi.f(38); leftMargin: DeckUi.f(14); rightMargin: DeckUi.f(14) }
        height: DeckUi.f(98)

        readonly property var week: { const _ = Net.days; return Net.recent(7) }
        readonly property var shown: usage.week[np.day] || { rx: 0, tx: 0, by: {}, key: "" }
        readonly property var nets: Net.byConnection([usage.shown]).slice(0, 3)
        readonly property real most: Math.max(1, ...usage.week.map(d => d.rx + d.tx))
        readonly property real weekTotal: usage.week.reduce((a, d) => a + d.rx + d.tx, 0)
        readonly property bool sel: np.kb && np.row === "usage"

        Caption {
            id: usageCap
            width: parent.width
            text: "Usage"
            trailing: "This week  " + Net.bytes(usage.weekTotal)
        }

        Column {
            id: dayInfo
            anchors { left: parent.left; top: usageCap.bottom; topMargin: DeckUi.f(10) }
            width: parent.width * 0.36
            spacing: DeckUi.f(4)
            Row {
                spacing: DeckUi.f(10)
                Text {
                    id: amount
                    text: Net.bytes(usage.shown.rx + usage.shown.tx)
                    color: DeckUi.text
                    font.family: DeckUi.mono
                    font.pixelSize: DeckUi.f(15)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: amount.baseline
                    text: np.day === 6 ? "today" : new Date(usage.shown.key + "T12:00").toLocaleDateString(Qt.locale(), "dddd")
                    color: DeckUi.faint
                    font.family: DeckUi.sans
                    font.pixelSize: DeckUi.f(11.5)
                }
            }
            Repeater {
                model: usage.nets
                Item {
                    required property var modelData
                    width: dayInfo.width
                    height: DeckUi.f(16)
                    readonly property real total: modelData.rx + modelData.tx
                    Text {
                        id: netName
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.42
                        elide: Text.ElideRight
                        text: modelData.name
                        color: DeckUi.dim
                        font.family: DeckUi.sans
                        font.pixelSize: DeckUi.f(11)
                    }
                    Rectangle {
                        anchors { left: netName.right; leftMargin: DeckUi.f(8); right: netBytes.left; rightMargin: DeckUi.f(8); verticalCenter: parent.verticalCenter }
                        height: DeckUi.f(3)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Rectangle {
                            width: parent.width * parent.parent.total / Math.max(1, usage.shown.rx + usage.shown.tx)
                            height: parent.height
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }
                    Text {
                        id: netBytes
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Net.bytes(parent.total)
                        color: DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(10.5)
                    }
                }
            }
            Text {
                visible: usage.nets.length === 0
                text: "Nothing yet"
                color: DeckUi.faint
                font.family: DeckUi.sans
                font.pixelSize: DeckUi.f(11)
            }
        }

        Row {
            id: bars
            anchors { left: dayInfo.right; leftMargin: DeckUi.f(28); right: parent.right
                      top: usageCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(10) }
            spacing: DeckUi.f(8)
            Repeater {
                model: usage.week
                Rectangle {
                    id: bar
                    required property var modelData
                    required property int index
                    readonly property bool picked: np.day === index
                    width: (bars.width - bars.spacing * 6) / 7
                    height: bars.height
                    radius: DeckUi.f(6)
                    color: picked && usage.sel ? DeckUi.sel : "transparent"
                    border.width: 1
                    border.color: picked && usage.sel ? DeckUi.selRim : "transparent"
                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: dayLabel.top; bottomMargin: DeckUi.f(4) }
                        width: Math.min(parent.width - DeckUi.f(12), DeckUi.f(24))
                        height: Math.max(2, (dayLabel.y - DeckUi.f(10)) * (bar.modelData.rx + bar.modelData.tx) / usage.most)
                        radius: DeckUi.f(3)
                        color: bar.index === 6 ? DeckUi.accent : bar.picked ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on height { Anim {} }
                        Behavior on color { CAnim {} }
                    }
                    Text {
                        id: dayLabel
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: DeckUi.f(3) }
                        text: bar.modelData.label
                        color: bar.picked ? DeckUi.text : DeckUi.faint
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(10)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: { np.row = "usage"; np.day = bar.index }
                    }
                }
            }
        }
    }

    Panel { around: usage; z: -1 }

    // Lists
    Item {
        id: lists
        anchors { left: parent.left; right: parent.right; top: usage.bottom; bottom: parent.bottom; topMargin: DeckUi.f(38)
                  leftMargin: DeckUi.f(14); rightMargin: DeckUi.f(14); bottomMargin: DeckUi.f(14) }
        readonly property real colW: (width - DeckUi.f(38)) / 2
        Panel { around: wifiCol; z: -1 }
        Panel { around: btCol; z: -1 }
        Item { id: wifiCol; width: lists.colW; height: lists.height }
        Item { id: btCol; x: lists.colW + DeckUi.f(38); width: lists.colW; height: lists.height }

        Caption {
            id: wifiCap
            width: lists.colW
            text: "Wi-Fi"
            trailing: Net.wifiOn ? Net.networks.length + (Net.networks.length === 1 ? " network" : " networks") : ""
        }
        ListView {
            id: wifiList
            anchors { left: parent.left; top: wifiCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
            width: lists.colW
            clip: true
            spacing: DeckUi.f(2)
            boundsBehavior: Flickable.StopAtBounds
            model: Net.wifiOn ? Net.networks : []
            currentIndex: np.wi
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Column {
                id: wrow
                required property var modelData
                required property int index
                readonly property bool sel: np.kb && np.row === "wifi" && np.wi === index
                readonly property bool asking: np.asking === modelData.name
                width: wifiList.width
                spacing: DeckUi.f(2)

                Connections {
                    target: wrow.modelData
                    function onConnectionFailed(reason) { const f = Object.assign({}, np.failed); f[wrow.modelData.name] = true; np.failed = f }
                }
                ListRow {
                    width: parent.width
                    glyph: Net.strengthGlyph(wrow.modelData.signalStrength)
                    title: wrow.modelData.name
                    subtitle: np.armed === "w:" + wrow.modelData.name ? "Forget again"
                        : wrow.modelData.stateChanging ? (wrow.modelData.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…")
                        : np.failed[wrow.modelData.name] ? "Couldn't connect"
                        : wrow.modelData.connected ? "" : wrow.modelData.known ? "Saved" : Net.secured(wrow.modelData) ? "Secured" : "Open"
                    badge: wrow.modelData.connected ? "Connected" : ""
                    badgeLive: true
                    meta: Math.round(wrow.modelData.signalStrength * 100) + "%"
                    selected: wrow.sel
                    onClicked: { np.row = "wifi"; np.wi = wrow.index; np.actWifi(wrow.modelData) }
                }
                Rectangle {
                    width: parent.width
                    height: DeckUi.f(38)
                    visible: wrow.asking
                    radius: DeckUi.innerRadius
                    color: DeckUi.sel
                    border.width: 1
                    border.color: DeckUi.selRim
                    TextInput {
                        id: psk
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: DeckUi.f(12) }
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: DeckUi.text
                        selectionColor: Qt.alpha(DeckUi.accent, 0.4)
                        font.family: DeckUi.mono
                        font.pixelSize: DeckUi.f(12.5)
                        clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !psk.text.length
                            text: "Password"
                            color: DeckUi.faint
                            font.family: DeckUi.sans
                            font.pixelSize: DeckUi.f(12)
                        }
                        Keys.onReturnPressed: np.submit(wrow.modelData, text)
                        Keys.onEnterPressed: np.submit(wrow.modelData, text)
                        Keys.onEscapePressed: { np.asking = ""; DeckUi.refocus() }
                        onActiveFocusChanged: if (!activeFocus && wrow.asking) np.asking = ""
                    }
                    onVisibleChanged: if (visible) { psk.text = ""; psk.forceActiveFocus() }
                }
            }
        }
        Text {
            anchors { left: wifiList.left; top: wifiList.top; topMargin: DeckUi.f(10); leftMargin: DeckUi.f(10) }
            visible: wifiList.count === 0
            text: Net.wifiOn ? "No networks" : "Wi-Fi is off"
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12)
        }

        Caption {
            id: btCap
            x: lists.colW + DeckUi.f(38)
            width: lists.colW
            text: "Bluetooth"
            trailing: np.scanning ? "Scanning…" : Net.btOn ? Net.devices.filter(d => d.connected).length + " connected" : ""
        }
        ListView {
            id: btList
            anchors { right: parent.right; top: btCap.bottom; bottom: parent.bottom; topMargin: DeckUi.f(8) }
            width: lists.colW
            clip: true
            spacing: DeckUi.f(2)
            boundsBehavior: Flickable.StopAtBounds
            model: Net.btOn ? Net.devices : []
            currentIndex: np.bi
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: ListRow {
                required property var modelData
                required property int index
                width: btList.width
                glyph: Net.deviceGlyph(modelData)
                title: modelData.name || modelData.address
                subtitle: np.armed === "b:" + modelData.address ? "Forget again"
                    : modelData.pairing ? "Pairing…"
                    : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                    : modelData.connected ? (Net.btSince[modelData.address] ? Net.duration(Date.now() - Net.btSince[modelData.address]) : "")
                    : modelData.paired ? "Paired" : "New"
                badge: modelData.connected ? "Connected" : ""
                badgeLive: true
                meta: modelData.batteryAvailable ? Math.round(modelData.battery <= 1 ? modelData.battery * 100 : modelData.battery) + "%" : ""
                selected: np.kb && np.row === "bt" && np.bi === index
                onClicked: { np.row = "bt"; np.bi = index; np.actBt(modelData) }
            }
        }
        Text {
            anchors { left: btList.left; top: btList.top; topMargin: DeckUi.f(10); leftMargin: DeckUi.f(10) }
            visible: btList.count === 0
            text: !Net.adapter ? "No adapter" : Net.btOn ? "No devices yet, scan to find some" : "Bluetooth is off"
            color: DeckUi.faint
            font.family: DeckUi.sans
            font.pixelSize: DeckUi.f(12)
        }
    }
}
