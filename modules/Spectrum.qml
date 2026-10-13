import QtQuick
import "root:/modules"

// Visualizer bars: `bands` of them across the width, rising from the bottom or, `centered`,
// out from the middle.
Item {
    id: sp
    property int bands: Visualizer.count
    property color color: DeckUi.accent
    property real gap: 2
    property bool centered: false
    property real floor: 2   // height of a silent bar

    readonly property var _v: sp.bands === Visualizer.count ? Visualizer.levels : Visualizer.bands(sp.bands)
    readonly property real _w: (sp.width - sp.gap * (sp.bands - 1)) / sp.bands

    Repeater {
        model: sp.bands
        Rectangle {
            required property int index
            x: index * (sp._w + sp.gap)
            width: sp._w
            height: sp.floor + (sp.height - sp.floor) * Math.min(1, sp._v[index] || 0)
            y: sp.centered ? (sp.height - height) / 2 : sp.height - height
            radius: Math.min(width / 2, 2)
            color: sp.color
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
