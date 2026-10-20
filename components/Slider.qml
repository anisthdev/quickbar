import QtQuick
import ".."

// Material 3 Expressive slider: a thick rounded track split by a slim
// handle, with an icon inside the start of the track and a stop dot at the
// end. Drag, click or scroll to change `value` (0-1); clicking the icon
// emits iconClicked instead. With `interactive` off it only shows a value.
Item {
    id: root

    property real value: 0
    property string icon
    property bool dimmed: false
    property bool interactive: true
    property color activeColor: dimmed ? Theme.outline : Theme.secondary
    property color trackColor: Theme.surface_container_highest
    // The icon's colour while it sits on the active part
    property color activeIconColor: Theme.on_secondary

    signal moved(real value)
    signal iconClicked

    readonly property real trackHeight: 40
    readonly property real gap: 6
    readonly property real handleWidth: mouse.pressed ? 2 : 4
    // Shown position; follows `value`, smoothly unless being dragged
    property real shown: value
    readonly property real handleX: shown * (width - handleWidth)

    implicitWidth: 240
    implicitHeight: trackHeight + 12

    Behavior on shown {
        enabled: !mouse.pressed
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    function setFromX(x) {
        const v = Math.max(0, Math.min(1, x / width));
        root.moved(v);
    }

    // Active part: from the start up to the handle
    Rectangle {
        id: active

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.handleX - root.gap)
        height: root.trackHeight
        topLeftRadius: Theme.radius
        bottomLeftRadius: Theme.radius
        topRightRadius: 4
        bottomRightRadius: 4
        color: root.activeColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }
    }

    // Inactive part: from the handle to the end
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + root.handleWidth + root.gap
        width: Math.max(0, root.width - x)
        height: root.trackHeight
        topLeftRadius: 4
        bottomLeftRadius: 4
        topRightRadius: Theme.radius
        bottomRightRadius: Theme.radius
        color: root.trackColor

        // Stop indicator
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: 2
            color: root.activeColor
            visible: parent.width > 24
        }
    }

    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX
        width: root.handleWidth
        height: root.trackHeight + 12
        radius: width / 2
        color: root.activeColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => root.setFromX(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.setFromX(event.x);
        }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.02 : -0.02))))
    }

    // Icon inside the start of the track; sits on the active part when
    // there's room, otherwise on the inactive track
    Item {
        id: iconArea

        anchors.verticalCenter: parent.verticalCenter
        x: 8
        width: 32
        height: 32

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 20
            color: active.width > 40 ? root.activeIconColor : Theme.on_surface

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }
}
