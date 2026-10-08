import QtQuick

NumberAnimation {
    duration: Motion.base
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.enter
}
