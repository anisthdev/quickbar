import QtQuick
import ".."

// A menu's power row: a title and a Material 3 switch, as at the top of
// Android's Wi-Fi and Bluetooth panels. The whole row toggles.
Rectangle {
    id: root

    property string text
    property bool checked: false
    // Entrance with the menu, see MenuReveal
    property bool shown: true

    signal toggled

    width: parent?.width ?? 0
    height: 56
    radius: Theme.radius
    color: Theme.surface_container_high

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Label {
        anchors.left: parent.left
        anchors.leftMargin: 18
        text: root.text
        color: Theme.on_surface
        font.pixelSize: 15
    }

    Switch {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: root.toggled()
    }

    MenuReveal {
        target: root
        shown: root.shown
    }
}
