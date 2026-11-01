import QtQuick
import "../.."
import "../../components"

// An album in the music menu's grid: its cover, title and artist, and the
// equalizer on the cover while a song of it plays. The grid draws the
// pick's fill behind it.
Item {
    id: root

    property var album
    property bool current: false
    readonly property bool playing: album && MpdPlayer.file.startsWith(album.dir + "/")

    signal clicked
    signal activated

    // Hover, under the cover and its text
    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Qt.alpha(Theme.on_surface, 0.06)
        visible: mouse.containsMouse && !root.current
    }

    AlbumArt {
        id: art

        x: 8
        y: 8
        size: root.width - 16
        source: root.album?.cover ? `file://${root.album.cover}` : ""
    }

    // Playing: a chip on the cover
    Rectangle {
        anchors.right: art.right
        anchors.top: art.top
        anchors.margins: 8
        width: 30
        height: 24
        radius: 12
        visible: root.playing
        color: Theme.primary_container

        Equalizer {
            anchors.centerIn: parent
            playing: MpdPlayer.playing
            color: Theme.on_primary_container
        }
    }

    Column {
        anchors.top: art.bottom
        anchors.topMargin: 8
        x: 10
        width: root.width - 20
        spacing: 1

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.album?.title ?? ""
            color: root.current ? Theme.on_secondary_container : Theme.on_surface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.album?.artist ?? ""
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 11
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
