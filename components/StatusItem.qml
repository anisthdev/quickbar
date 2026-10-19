import QtQuick
import ".."

// One icon + label entry inside the status segment.
Pill {
    id: root

    property alias icon: icon.name
    property alias text: label.text
    property alias iconSize: icon.size
    property color foreground: Theme.on_surface

    padding: 15
    implicitHeight: Theme.barHeight - 10
    color: hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    clickable: true

    Icon {
        id: icon
        color: root.foreground
    }

    Label {
        id: label
        color: root.foreground
        visible: text !== ""
    }
}
