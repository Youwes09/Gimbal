import QtQuick
import QtQuick.Shapes
import "root:/modules"

// Two series on a shared scale: `a` as a curve with a soft fill, `b` as a plain curve. New
// samples enter past the right edge and slide into place, so the graph moves instead of
// stepping; the scale eases when the peak changes.
Item {
    id: sp
    property var a: []
    property var b: []
    property int span: 60
    property int interval: 1000
    property color colorA: DeckUi.accent
    property color colorB: DeckUi.dim
    readonly property real peakTarget: Math.max(1, ...sp.a, ...sp.b)
    property real peak: 1
    onPeakTargetChanged: peak = peakTarget
    Behavior on peak { Anim { duration: Motion.slow } }

    readonly property real step: sp.width / Math.max(1, sp.span - 2)
    // Each new sample slides in with an ease-out instead of gliding the whole interval:
    // every animation frame repaints the deck, so this keeps the motion and cuts the frames.
    property real phase: 1
    onAChanged: glide.restart()
    NumberAnimation { id: glide; target: sp; property: "phase"; from: 0; to: 1; duration: Math.min(sp.interval, 450); easing.type: Easing.OutCubic }

    clip: true

    // Catmull-Rom through the samples, newest one step past the right edge.
    function curve(s) {
        const n = s.length, h = sp.height, out = []
        if (n < 2) return out
        const P = i => {
            const j = Math.max(0, Math.min(n - 1, i))
            return { x: sp.width + sp.step - (n - 1 - j) * sp.step,
                     y: h - 1 - (s[j] / (sp.peak * 1.15)) * (h - 2) }
        }
        for (let i = 0; i < n - 1; i++) {
            const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2)
            for (let t = 0; t < 1; t += 0.25) {
                const t2 = t * t, t3 = t2 * t
                const f = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                out.push(Qt.point(f(p0.x, p1.x, p2.x, p3.x), Math.min(h - 1, f(p0.y, p1.y, p2.y, p3.y))))
            }
        }
        const last = P(n - 1)
        out.push(Qt.point(last.x, last.y))
        return out
    }
    readonly property var lineA: { const _ = sp.peak + sp.width + sp.height; return sp.curve(sp.a) }
    readonly property var lineB: { const _ = sp.peak + sp.width + sp.height; return sp.curve(sp.b) }
    readonly property var fillA: sp.lineA.length
        ? sp.lineA.concat([Qt.point(sp.lineA[sp.lineA.length - 1].x, sp.height), Qt.point(sp.lineA[0].x, sp.height)]) : []

    Shape {
        x: -sp.phase * sp.step
        width: sp.width + sp.step * 2
        height: sp.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0; y2: sp.height
                GradientStop { position: 0; color: Qt.alpha(sp.colorA, 0.22) }
                GradientStop { position: 1; color: Qt.alpha(sp.colorA, 0) }
            }
            PathPolyline { path: sp.fillA }
        }
        ShapePath {
            strokeColor: sp.colorB
            strokeWidth: 1
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: sp.lineB }
        }
        ShapePath {
            strokeColor: sp.colorA
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: sp.lineA }
        }
    }
}
