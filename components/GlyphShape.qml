import QtQuick
import QtQuick.Shapes

// A filled SVG path drawn in viewport units and scaled by `unit` pixels
Shape {
    id: root

    property string d
    property real unit: 1
    property color fill: "black"
    property color stroke: "transparent"
    property real strokeWidth: 0

    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
        xScale: root.unit
        yScale: root.unit
    }

    ShapePath {
        fillColor: root.fill
        strokeColor: root.stroke
        strokeWidth: root.strokeWidth
        joinStyle: ShapePath.RoundJoin
        // Android paths use non-zero winding; the "9" overlaps itself
        fillRule: ShapePath.WindingFill

        PathSvg {
            path: root.d
        }
    }
}
