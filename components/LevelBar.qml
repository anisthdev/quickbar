import QtQuick
import ".."

// A thick level bar: the filled part, a small gap, then the rest of the
// track with a stop dot; rounded outer ends, tight inner edges. For levels
// that are only shown (battery, volume, brightness), so there's no handle.
// `fillWidth` is exposed for anything riding on the filled part.
Item {
    id: root

    // 0 to 1
    property real value: 0
    property color color: Theme.primary
    property color trackColor: Theme.primary_container
    // Narrowest the filled part gets, e.g. room for an icon inside it
    property real minFill: outer
    property int duration: 300

    readonly property real outer: Theme.radius
    readonly property real inner: 3
    readonly property real gap: 4
    property real shown: Math.max(0, Math.min(1, value))
    readonly property real fillWidth: Math.max(minFill, shown * (width - gap))

    implicitHeight: 40

    Behavior on shown {
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    Rectangle {
        width: root.fillWidth
        height: parent.height
        topLeftRadius: root.outer
        bottomLeftRadius: root.outer
        topRightRadius: root.shown >= 1 ? root.outer : root.inner
        bottomRightRadius: root.shown >= 1 ? root.outer : root.inner
        color: root.color
    }

    Rectangle {
        x: root.fillWidth + root.gap
        width: Math.max(0, parent.width - x)
        height: parent.height
        visible: width > 0
        topLeftRadius: root.inner
        bottomLeftRadius: root.inner
        topRightRadius: root.outer
        bottomRightRadius: root.outer
        color: root.trackColor

        // Stop indicator
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.width > 30
            width: 6
            height: 6
            radius: 3
            color: root.color
        }
    }
}
