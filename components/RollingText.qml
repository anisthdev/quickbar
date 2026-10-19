import QtQuick
import ".."

// Text whose characters roll like an odometer when they change: the old one
// slides up and out as the new one comes up from below. Only characters
// that actually change move, so "4 mins" -> "3 mins" rolls just the digit.
Row {
    id: root

    property string text
    property color color: Theme.on_surface
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize
    property int fontWeight: Font.Bold

    anchors.verticalCenter: parent?.verticalCenter

    Repeater {
        model: root.text.length

        Item {
            id: cell

            required property int index
            readonly property string ch: root.text.charAt(index)
            // Which of the two labels holds the current character
            property bool flipped: false

            width: (flipped ? b : a).implicitWidth
            height: a.implicitHeight
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            Component.onCompleted: a.text = ch

            onChChanged: {
                const incoming = flipped ? a : b;
                const outgoing = flipped ? b : a;
                incoming.text = ch;
                outRoll.target = outgoing;
                inRoll.target = incoming;
                roll.restart();
                flipped = !flipped;
            }

            ParallelAnimation {
                id: roll

                NumberAnimation {
                    id: outRoll
                    property: "y"
                    from: 0
                    to: -cell.height
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
                NumberAnimation {
                    id: inRoll
                    property: "y"
                    from: cell.height
                    to: 0
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            Text {
                id: a
                color: root.color
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: root.fontWeight
                // Tabular figures, so a ticking timer keeps its width
                font.features: {
                    "tnum": 1
                }
            }

            Text {
                id: b
                y: cell.height
                color: root.color
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.weight: root.fontWeight
                // Tabular figures, so a ticking timer keeps its width
                font.features: {
                    "tnum": 1
                }
            }
        }
    }
}
