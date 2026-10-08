import QtQuick

NumberAnimation {
    duration: Motion.exit
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.leave
}
