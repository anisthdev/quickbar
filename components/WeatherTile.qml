import QtQuick
import ".."

// A weather detail tile, as in Pixel Weather: an icon and title, a large
// value with an optional unit, and a caption. An optional accessory icon
// (e.g. a wind direction arrow) sits in the top-right corner.
Rectangle {
    id: root

    property string icon
    property string title
    property string value
    property string unit
    property string caption
    property string accessoryIcon
    property real accessoryRotation: 0

    height: 98
    radius: 20
    color: Theme.surface_container_high

    Row {
        x: 12
        y: 12
        spacing: 5

        Icon {
            name: root.icon
            size: 14
            color: Theme.on_surface_variant
        }

        Label {
            text: root.title
            color: Theme.on_surface_variant
            font.pixelSize: 12
        }
    }

    Icon {
        x: root.width - width - 12
        y: 12
        visible: root.accessoryIcon !== ""
        name: root.accessoryIcon
        size: 16
        rotation: root.accessoryRotation
        color: Theme.primary
    }

    Row {
        x: 12
        y: 34
        spacing: 3

        Label {
            anchors.verticalCenter: undefined
            text: root.value
            color: Theme.on_surface
            font.pixelSize: 24
            font.weight: Font.Normal
        }

        Label {
            anchors.verticalCenter: undefined
            anchors.baseline: parent.children[0].baseline
            visible: text !== ""
            text: root.unit
            color: Theme.on_surface_variant
            font.pixelSize: 12
        }
    }

    Label {
        anchors.verticalCenter: undefined
        x: 12
        y: root.height - height - 12
        width: root.width - 24
        text: root.caption
        color: Theme.on_surface_variant
        font.pixelSize: 11
        font.weight: Font.Medium
        elide: Text.ElideRight
    }
}
