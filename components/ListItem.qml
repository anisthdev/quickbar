import QtQuick
import ".."

// One row of a Material 3 Expressive grouped list, as in Android 16's quick
// settings dialogs: rows of a group share round outer corners and have
// tight corners between them. A selected row fills with the primary colour
// and rounds all its corners. Children go on the right (battery, check
// mark...). Rows stagger in with their menu through `shown`/`revealIndex`.
Rectangle {
    id: root

    property string icon
    property string text
    property bool first: false
    property bool last: false
    property bool selected: false
    property bool clickable: false
    // Entrance with the menu, see MenuReveal
    property bool shown: true
    property int revealIndex: 0
    default property alias trailing: trailingRow.data

    signal clicked

    readonly property real outerRadius: 20
    readonly property real innerRadius: 6
    // Not readonly, so the corner changes can animate
    property real topCorners: selected || first ? outerRadius : innerRadius
    property real bottomCorners: selected || last ? outerRadius : innerRadius

    width: parent?.width ?? 0
    height: 56
    topLeftRadius: topCorners
    topRightRadius: topCorners
    bottomLeftRadius: bottomCorners
    bottomRightRadius: bottomCorners
    color: selected ? Theme.primary_container : clickable && mouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

    Behavior on topCorners {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on bottomCorners {
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

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: root.selected ? Theme.primary : Theme.primary_container

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 20
            color: root.selected ? Theme.on_primary : Theme.on_primary_container
        }
    }

    Label {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: trailingRow.left
        anchors.rightMargin: 12
        text: root.text
        color: root.selected ? Theme.on_primary_container : Theme.on_surface
        elide: Text.ElideRight
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    MenuReveal {
        target: root
        shown: root.shown
        index: root.revealIndex
    }
}
