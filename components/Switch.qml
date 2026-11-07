import QtQuick
import ".."

// A compact switch in our corners: when on, a secondary track (calmer than
// primary) with a large handle; when off, an outlined track with a small
// handle. Three grooves mark the handle as a grip, and it grows while
// pressed.
Item {
    id: root

    property bool checked: false

    signal toggled

    // Our row corners, scaled to this height
    readonly property real corner: 7

    implicitWidth: 42
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: root.corner
        color: root.checked ? Theme.secondary : Theme.surface_container_highest
        border.width: root.checked ? 0 : 1.5
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }
    }

    Rectangle {
        id: handle

        readonly property real size: mouse.pressed ? 20 : root.checked ? 18 : 14

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - (root.height - height) / 2 : (root.height - height) / 2
        width: size
        height: size
        // Follows the track's corners, keeping the even gap between them
        radius: Math.max(3, root.corner - (root.height - size) / 2)
        color: root.checked ? Theme.on_secondary : Theme.outline

        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: 3

                Rectangle {
                    width: 1
                    height: 8
                    radius: 0.5
                    color: root.checked ? Theme.secondary : Theme.surface_container_highest

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animNormal
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
