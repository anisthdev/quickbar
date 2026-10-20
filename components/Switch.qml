import QtQuick
import ".."

// Material 3 switch: when on, a secondary track (calmer than primary) with
// a large handle carrying a check mark; when off, an outlined track with a
// small handle. The handle grows while pressed.
Item {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.secondary : Theme.surface_container_highest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }
    }

    Rectangle {
        id: handle

        readonly property real size: mouse.pressed ? 28 : root.checked ? 24 : 16

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - (root.height - height) / 2 : (root.height - height) / 2
        width: size
        height: size
        radius: size / 2
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

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: 16
            color: Theme.secondary
            opacity: root.checked ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
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
