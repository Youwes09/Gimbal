pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool enabled: false
    property var devices: []
    property bool busy: false

    function refresh() {
        _get.running = false
        Qt.callLater(() => _get.running = true)
    }
    Component.onCompleted: root.refresh()
    property Timer _poll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: root.refresh()
    }

    function toggle() {
        root.busy = true
        _cmd.command = ["sh", "-c", root.enabled ? "bluetoothctl power off" : "bluetoothctl power on"]
        _cmd.running = true
    }
    function connectDev(mac) {
        root.busy = true
        _cmd.command = ["sh", "-c", 'bluetoothctl connect "$1" >/dev/null 2>&1', "_", mac]
        _cmd.running = true
    }
    function disconnectDev(mac) {
        root.busy = true
        _cmd.command = ["sh", "-c", 'bluetoothctl disconnect "$1" >/dev/null 2>&1', "_", mac]
        _cmd.running = true
    }

    property Process _cmd: Process {
        onExited: { root.busy = false; root.refresh() }
    }

    property Process _get: Process {
        command: ["sh", "-c",
            "bluetoothctl show; echo '@@@'; "
            + "for m in $(bluetoothctl devices Paired | cut -d' ' -f2); do "
            + 'echo "##$m"; bluetoothctl info "$m"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("@@@")
                const showBlock = parts[0] || ""
                const en = /Powered:\s*yes/.test(showBlock)
                const rest = parts[1] || ""
                const chunks = rest.split(/^##/m).filter(c => c.trim().length > 0)
                const devs = []
                for (const c of chunks) {
                    const mac = c.split("\n")[0].trim()
                    if (!mac) continue
                    const nameM = c.match(/\n\s*Name:\s*(.+)/)
                    devs.push({
                        mac,
                        name: nameM ? nameM[1].trim() : mac,
                        connected: /Connected:\s*yes/.test(c)
                    })
                }
                devs.sort((a, b) => b.connected - a.connected)
                root.enabled = en
                root.devices = devs
            }
        }
    }
}
