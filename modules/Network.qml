pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool enabled: true
    property bool connected: false
    property string activeSsid: ""
    property var networks: []
    property bool busy: false

    property string authTarget: ""
    property string authError: ""

    function refresh() {
        _get.running = false
        Qt.callLater(() => _get.running = true)
    }
    Component.onCompleted: {
        root.refresh()
        root.rescan()
    }
    property Timer _poll: Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: root.refresh()
    }
    property Timer _scanPoll: Timer {
        interval: 20000; running: true; repeat: true
        onTriggered: root.rescan()
    }

    function toggle() {
        root.busy = true
        _cmd.command = ["sh", "-c", root.enabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        _cmd.running = true
    }
    function rescan() {
        Quickshell.execDetached(["nmcli", "dev", "wifi", "rescan"])
    }
    function connect(ssid) {
        root.authError = ""
        root.busy = true
        _connectCmd.ssid = ssid
        _connectCmd.command = ["sh", "-c", 'nmcli dev wifi connect "$1" 2>&1', "_", ssid]
        _connectCmd.running = true
    }
    function connectWithPassword(ssid, password) {
        root.authError = ""
        root.busy = true
        _connectCmd.ssid = ssid
        _connectCmd.command = ["sh", "-c",
            'nmcli dev wifi connect "$1" password "$2" hidden yes 2>&1', "_", ssid, password]
        _connectCmd.running = true
    }
    function cancelAuth() {
        root.authTarget = ""
        root.authError = ""
    }
    function disconnect(ssid) {
        root.busy = true
        _cmd.command = ["sh", "-c", 'nmcli con down id "$1" >/dev/null 2>&1', "_", ssid]
        _cmd.running = true
    }

    property Process _cmd: Process {
        onExited: { root.busy = false; root.refresh() }
    }

    property Process _connectCmd: Process {
        property string ssid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text || ""
                root.busy = false
                const ok = /successfully activated/i.test(out)
                if (ok) {
                    root.authTarget = ""
                    root.authError = ""
                } else {
                    root.authTarget = _connectCmd.ssid
                    root.authError = out.trim().split("\n").pop() || "connection failed"
                }
                root.refresh()
            }
        }
    }

    property Process _get: Process {
        command: ["sh", "-c",
            'echo "R:$(nmcli radio wifi)"; nmcli -t -f active,ssid,signal,security dev wifi list --rescan no 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0)
                let en = true
                const byId = new Map()
                for (const l of lines) {
                    if (l.indexOf("R:") === 0) { en = l.slice(2).trim() === "enabled"; continue }
                    const parts = l.split(":")
                    const active = parts[0] === "yes"
                    const ssid = parts[1]
                    const signal = parseInt(parts[2] || "0") || 0
                    const secure = parts.slice(3).join(":").length > 0
                    if (!ssid) continue
                    const prev = byId.get(ssid)
                    if (!prev || active || (!prev.active && signal > prev.signal))
                        byId.set(ssid, { ssid, signal, secure, active })
                }
                const nets = Array.from(byId.values())
                nets.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                root.enabled = en
                root.networks = nets
                const cur = nets.find(n => n.active)
                root.connected = !!cur
                root.activeSsid = cur ? cur.ssid : ""
            }
        }
    }
}
