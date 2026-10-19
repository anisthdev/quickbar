import QtQuick
import ".."

// Material 3 small badge: a 6px dot in the error colour, ringed in the
// surface behind it so it stands off the icon. Pops in and out.
Rectangle {
    id: root

    property bool shown: false
    property color ring: Theme.tertiary_container

    width: 9
    height: 9
    radius: width / 2
    color: root.ring
    scale: shown ? 1 : 0
    visible: scale > 0

    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? Theme.animNormal : Theme.animFast
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 2
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 6
        height: 6
        radius: 3
        color: Theme.error
    }
}
