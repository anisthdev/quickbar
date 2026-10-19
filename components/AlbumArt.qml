import Quickshell.Widgets
import QtQuick
import ".."

// Album art cropped to a rounded square, or, for a song without art, a
// tonal tile with a music note.
ClippingRectangle {
    id: root

    property string source
    property real size: 48

    implicitWidth: size
    implicitHeight: size
    radius: size * 0.22
    color: Theme.primary_container

    Icon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        name: "media_music_note"
        size: root.size * 0.5
        color: Theme.on_primary_container
    }

    Image {
        id: art

        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Crossfade between songs
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animNormal
            }
        }
    }
}
