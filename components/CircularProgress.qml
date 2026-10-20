import QtQuick
import QtQuick.Shapes
import ".."

// Material 3 Expressive circular progress indicator: the indicator arc from
// twelve o'clock, a gap either side, then the track for the rest, with
// round ends. Without a value (`indeterminate`) a short arc spins instead.
Item {
    id: root

    // 0 to 1
    property real progress: 0
    property bool indeterminate: false
    property real size: 22
    property real thickness: 3
    property color color: Theme.primary
    property color trackColor: Theme.primary_container

    readonly property real radius: (size - thickness) / 2
    // Gap between indicator and track, as an angle, with room for the caps
    readonly property real gapAngle: (thickness + 3) / radius * 180 / Math.PI
    property real shown: Math.max(0, Math.min(1, progress))
    readonly property real sweep: indeterminate ? 90 : 360 * shown

    implicitWidth: size
    implicitHeight: size

    Behavior on shown {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    // Track, from after the indicator round to before it
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: 360 - root.sweep - 2 * root.gapAngle > 0

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + root.sweep + root.gapAngle + spin.angle
                sweepAngle: Math.max(0, 360 - root.sweep - 2 * root.gapAngle)
            }
        }
    }

    // Indicator
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.sweep > 0

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + spin.angle
                // A full ring closes on itself without a seam
                sweepAngle: root.sweep >= 360 ? 359.9 : root.sweep
            }
        }
    }

    Item {
        id: spin

        property real angle: 0

        NumberAnimation on angle {
            running: root.indeterminate && root.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1200
        }
    }
}
