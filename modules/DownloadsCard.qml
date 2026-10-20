import Quickshell
import QtQuick
import ".."
import "../components"

// Every unfinished download, newest first: its name, a wavy progress bar
// while it downloads, how much is done and how fast, and pause or resume.
// From the Transmission singleton.
Dropdown {
    id: root

    menuWidth: 360
    title: "Downloads"

    Repeater {
        model: ScriptModel {
            values: Transmission.active.map(t => t.id)
        }

        Rectangle {
            id: row

            required property int modelData
            required property int index
            readonly property var torrent: Transmission.byId[modelData] ?? {}
            readonly property bool first: index === 0
            readonly property bool last: index === Transmission.active.length - 1
            readonly property bool paused: torrent.status === 0
            readonly property bool downloading: torrent.status === 4

            width: parent.width
            height: info.implicitHeight + 28
            topLeftRadius: first ? Theme.radius : 3
            topRightRadius: first ? Theme.radius : 3
            bottomLeftRadius: last ? Theme.radius : 3
            bottomRightRadius: last ? Theme.radius : 3
            color: Theme.surface_container_high

            Column {
                id: info

                x: 16
                y: 14
                width: parent.width - 32 - toggle.width
                spacing: 4

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: row.torrent.name
                    color: Theme.on_surface
                    font.pixelSize: 14
                    elide: Text.ElideMiddle
                }

                LinearProgress {
                    width: parent.width
                    progress: row.torrent.percentDone
                    indeterminate: row.torrent.status === 1 || row.torrent.status === 2
                    wavy: row.downloading
                    thickness: 4
                    color: row.paused ? Theme.outline : Theme.primary
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: {
                        const t = row.torrent;
                        const have = Transmission.size(t.sizeWhenDone - t.leftUntilDone);
                        return `${Math.floor(t.percentDone * 100)}% · ${have} of ${Transmission.size(t.sizeWhenDone)} · ${Transmission.state(t)}`;
                    }
                    color: row.torrent.error ? Theme.error : Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            IconButton {
                id: toggle

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 40
                implicitHeight: 40
                icon: row.paused ? "media_play_arrow" : "media_pause"
                iconSize: 18
                color: Theme.on_surface_variant
                onClicked: Transmission.toggle(row.torrent)
            }

            MenuReveal {
                target: row
                shown: root.open
                index: row.index + 1
            }
        }
    }

    Label {
        anchors.verticalCenter: undefined
        visible: Transmission.active.length === 0
        leftPadding: 8
        bottomPadding: 6
        text: Transmission.finished ? `${Transmission.finished.name} finished` : "Nothing downloading"
        color: Theme.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Normal
        width: parent.width
        elide: Text.ElideMiddle
    }
}
