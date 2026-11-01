import QtQuick
import "../.."
import "../../components"

// A song in the music menu's lists: its cover, title, "artist · album" and
// length, and the equalizer while it's the one playing; a playlist's song
// whose file has gone is dimmed. Text only: the list draws the row's
// background and the sliding pick under it.
Item {
    id: root

    property var song
    property bool current: false
    property bool playing: false
    readonly property bool missing: song?.missing ?? false
    // What shows under the title (artist · album, by default)
    property string detail: [song?.artist, song?.album].filter(s => s).join("  ·  ")
    // A track number in place of the cover (an album's page)
    property int number: 0

    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal activated

    height: 58

    function clock(seconds) {
        return `${Math.floor(seconds / 60)}:${String(Math.round(seconds) % 60).padStart(2, "0")}`;
    }

    AlbumArt {
        id: art

        x: 9
        anchors.verticalCenter: parent.verticalCenter
        visible: root.number === 0
        size: 40
        source: root.song?.cover ? `file://${root.song.cover}` : ""
    }

    Label {
        id: number

        x: 9
        width: 40
        visible: root.number > 0
        text: root.number
        horizontalAlignment: Text.AlignHCenter
        color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
        font.family: Theme.monoFamily
        font.pixelSize: 13
    }

    Column {
        opacity: root.missing ? 0.5 : 1
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: trailing.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.song?.title ?? ""
            color: root.current ? Theme.on_secondary_container : root.playing ? Theme.primary : Theme.on_surface
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== ""
            text: root.missing ? "Not in the library any more" : root.detail
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 12
            font.weight: Font.Normal
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.playing
            playing: MpdPlayer.playing
            color: root.current ? Theme.on_secondary_container : Theme.primary
        }

        Label {
            text: root.clock(root.song?.seconds ?? 0)
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            font.family: Theme.monoFamily
            font.pixelSize: 12
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
