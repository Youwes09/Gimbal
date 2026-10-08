import QtQuick

ColorAnimation {
    duration: Motion.fast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.enter
}
