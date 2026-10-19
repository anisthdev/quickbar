import QtQuick
import ".."

// A rounded background that sizes itself to its content and animates
// whenever that content grows or shrinks.
Rectangle {
    id: root

    default property alias content: row.data
    property real padding: 12
    property alias spacing: row.spacing
    property bool clickable: false
    // Off when the content animates its own size, so the pill tracks it
    // frame by frame instead of trailing behind it
    property bool animateWidth: true
    readonly property alias hovered: mouse.containsMouse
    readonly property alias pressed: mouse.pressed
    // Material hover and press state layer, in the content's colour
    property bool stateLayer: clickable
    property color stateColor: Theme.on_surface

    signal clicked(var event)
    signal scrolled(var event)

    implicitHeight: Theme.barHeight
    // Whole pixels, so icons after fractional-width text stay sharp
    implicitWidth: Math.ceil(row.implicitWidth + padding * 2)
    radius: Theme.radius
    color: Theme.background
    clip: true

    Behavior on implicitWidth {
        enabled: root.animateWidth
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.animNormal
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => root.clicked(event)
        onWheel: event => root.scrolled(event)
    }

    Rectangle {
        anchors.fill: parent
        visible: root.stateLayer
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.stateColor
        opacity: root.pressed ? 0.12 : root.hovered ? 0.08 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
