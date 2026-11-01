import Quickshell.Widgets
import QtQuick
import "../.."
import "../../components"

// A playlist's picture: its first four covers in a 2×2 square, or the one
// when it has fewer, rounded as album art is.
ClippingRectangle {
    id: root

    property var covers: []
    property real size: 48

    width: size
    height: size
    radius: size * 0.22
    color: Theme.primary_container

    Icon {
        anchors.centerIn: parent
        visible: root.covers.length === 0
        name: "media_music_note"
        size: root.size * 0.5
        color: Theme.on_primary_container
    }

    Grid {
        visible: root.covers.length >= 4
        columns: 2

        Repeater {
            model: root.covers.length >= 4 ? root.covers.slice(0, 4) : []

            Image {
                required property string modelData

                width: root.size / 2
                height: root.size / 2
                source: `file://${modelData}`
                sourceSize: Qt.size(root.size, root.size)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    Image {
        anchors.fill: parent
        visible: root.covers.length > 0 && root.covers.length < 4
        source: root.covers.length > 0 && root.covers.length < 4 ? `file://${root.covers[0]}` : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
