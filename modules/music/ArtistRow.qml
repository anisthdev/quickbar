import QtQuick
import "../.."
import "../../components"

// An artist in the music menu's list: their picture, name, and how many
// songs and albums of theirs there are; the equalizer while one plays.
Item {
    id: root

    property var artist
    property bool current: false
    readonly property bool playing: artist && artist.files.includes(MpdPlayer.file)
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal activated

    height: 58

    ArtistPicture {
        id: picture

        x: 9
        anchors.verticalCenter: parent.verticalCenter
        size: 40
        name: root.artist?.name ?? ""
        cover: root.artist?.cover ?? ""
    }

    Column {
        anchors.left: picture.right
        anchors.leftMargin: 14
        anchors.right: eq.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.artist?.name ?? ""
            color: root.current ? Theme.on_secondary_container : root.playing ? Theme.primary : Theme.on_surface
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: {
                const a = root.artist;
                if (!a)
                    return "";
                const songs = `${a.songs} ${a.songs === 1 ? "song" : "songs"}`;
                return a.albums > 1 ? `${songs}  ·  ${a.albums} albums` : songs;
            }
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    Equalizer {
        id: eq

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: root.playing
        width: visible ? implicitWidth : 0
        playing: MpdPlayer.playing
        color: root.current ? Theme.on_secondary_container : Theme.primary
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
