import QtQuick
import "../.."
import "../../components"

// A playlist in the music menu's list: its covers, name, and how many songs
// and how long, with any whose files have gone.
Item {
    id: root

    property var playlist
    property bool current: false
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal activated

    height: 58

    function runtime(seconds) {
        const minutes = Math.round(seconds / 60);
        return minutes >= 60 ? `${Math.floor(minutes / 60)} h ${minutes % 60} min` : `${minutes} min`;
    }

    MosaicArt {
        id: art

        x: 9
        anchors.verticalCenter: parent.verticalCenter
        size: 40
        covers: root.playlist?.covers ?? []
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.playlist?.name ?? ""
            color: root.current ? Theme.on_secondary_container : Theme.on_surface
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: {
                const p = root.playlist;
                if (!p)
                    return "";
                const n = p.tracks.length;
                const missing = p.tracks.filter(t => t.missing).length;
                return [`${n} ${n === 1 ? "song" : "songs"}`, root.runtime(p.seconds), missing ? `${missing} missing` : ""].filter(x => x).join("  ·  ");
            }
            color: root.current ? Theme.on_secondary_container : Theme.on_surface_variant
            opacity: root.current ? 0.8 : 1
            font.pixelSize: 12
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
