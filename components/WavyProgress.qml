import QtQuick
import QtQuick.Shapes
import ".."

// Android's wavy media progress bar: the played part is a wave that flows
// while playing and flattens out when paused, the rest a plain track, with
// an M3 slider handle between them. Drag or click to seek.
Item {
    id: root

    property real progress: 0
    property bool playing: false
    property color color: Theme.primary
    property color trackColor: Theme.surface_container_highest

    signal seek(real fraction)

    readonly property real wavelength: 28
    readonly property real stroke: 4
    // While dragging, follow the pointer instead of the player
    readonly property real shownProgress: mouse.pressed ? mouse.dragProgress : progress
    readonly property real handleX: Math.max(0, Math.min(1, shownProgress)) * width

    property real phase: 0
    property real amplitude: playing ? 3 : 0

    implicitHeight: 24

    Behavior on amplitude {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation on phase {
        running: root.playing
        loops: Animation.Infinite
        from: 0
        to: 2 * Math.PI
        duration: 1400
    }

    // Unplayed track, from just past the handle to the end
    Rectangle {
        x: root.handleX + 6
        width: Math.max(0, root.width - x)
        height: root.stroke
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.trackColor
    }

    // Played part as a wave, up to just before the handle
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    const end = Math.max(0, root.handleX - 6);
                    const mid = root.height / 2;
                    const points = [];
                    for (let x = root.stroke / 2; x <= end; x += 2)
                        points.push(Qt.point(x, mid + root.amplitude * Math.sin(x / root.wavelength * 2 * Math.PI - root.phase)));
                    if (points.length === 0)
                        points.push(Qt.point(root.stroke / 2, mid));
                    return points;
                }
            }
        }
    }

    // M3 slider handle
    Rectangle {
        x: root.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: mouse.pressed ? 3 : 4
        height: 18
        radius: width / 2
        color: root.color
    }

    MouseArea {
        id: mouse

        property real dragProgress: 0

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => dragProgress = Math.max(0, Math.min(1, event.x / width))
        onPositionChanged: event => dragProgress = Math.max(0, Math.min(1, event.x / width))
        onReleased: root.seek(dragProgress)
    }
}
