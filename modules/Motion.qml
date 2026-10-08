pragma Singleton

import QtQuick

// One set of timings and curves for every animation in the shell. Things decelerate in and
// accelerate out; nothing overshoots.
QtObject {
    readonly property int fast: 120     // hover, selection, colour
    readonly property int base: 200     // layout changes, crossfades, list moves
    readonly property int slow: 320     // whole surfaces arriving
    readonly property int exit: 160     // whole surfaces leaving

    readonly property var enter: [0.2, 0, 0, 1, 1, 1]
    readonly property var leave: [0.4, 0, 1, 1, 1, 1]
}
