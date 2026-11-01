import Quickshell.Widgets
import QtQuick
import "../.."
import "../../components"

// An artist's picture: one of their covers in a circle, or their initial on
// a tonal circle when there's none.
ClippingRectangle {
    id: root

    property string name
    property string cover
    property real size: 40

    width: size
    height: size
    radius: size / 2
    color: Theme.tertiary_container

    Label {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: root.name.slice(0, 1).toUpperCase()
        color: Theme.on_tertiary_container
        font.pixelSize: root.size * 0.42
        font.weight: Font.DemiBold
    }

    Image {
        id: image

        anchors.fill: parent
        source: root.cover ? `file://${root.cover}` : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
