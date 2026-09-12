pragma Singleton

import QtQuick
import Quickshell.Services.UPower
import "root:/modules"

QtObject {
    id: root

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat && bat.isLaptopBattery
    readonly property int pct: hasBattery ? Math.round(bat.percentage * 100) : 100
    readonly property bool charging: hasBattery && bat.state === UPowerDeviceState.Charging

    property bool _warned20: false
    property bool _warned10: false

    onPctChanged: root._check()
    onChargingChanged: root._check()

    function _check() {
        if (!root.hasBattery) return
        if (root.charging || root.pct > 25) { root._warned20 = false; root._warned10 = false }
        if (root.charging) return

        if (root.pct <= 10 && !root._warned10) {
            root._warned10 = true
            root._fire("Battery critical", root.pct + "% remaining — plug in now", "critical")
        } else if (root.pct <= 20 && !root._warned20) {
            root._warned20 = true
            root._fire("Battery low", root.pct + "% remaining", "normal")
        }
    }

    function _fire(summary, body, urgency) {
        Notifications.notifySynthetic({
            app: "Battery",
            summary: summary,
            body: body,
            urgency: urgency
        })
    }
}
