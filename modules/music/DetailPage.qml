import QtQuick
import "../.."
import "../../components"

// A page in the music menu, over its tab: an album, an artist, a playlist
// or the queue. A header (the cover, the artist's round picture or the
// playlist's mosaic, the name, what it is, its buttons; for an artist,
// their albums as small covers) over its songs. The menu drives its keys
// through `list`.
Item {
    id: root

    // { kind: "album" | "artist" | "playlist" | "queue", title, subtitle,
    //   info, cover, covers (a playlist's), albums (an artist's),
    //   actions: [{ id, label, icon, primary }] }
    property var page: null
    // The songs, given apart from the page so the queue's and a playlist's
    // can follow mpd
    property var songs: []
    readonly property alias list: songList
    readonly property string kind: page?.kind ?? ""
    readonly property var actions: page?.actions ?? [
        {
            id: "play",
            label: "Play  P",
            icon: "media_play_arrow",
            primary: true
        },
        {
            id: "shuffle",
            label: "Shuffle  R",
            icon: "media_shuffle",
            primary: false
        }
    ]

    signal play(int index)
    signal action(string id)
    signal openAlbum(var album)
    signal back

    Item {
        id: header

        width: parent.width
        height: Math.max(120, details.implicitHeight)

        AlbumArt {
            visible: root.kind === "album"
            size: 120
            source: root.page?.cover ? `file://${root.page.cover}` : ""
        }

        ArtistPicture {
            visible: root.kind === "artist"
            size: 120
            name: root.page?.title ?? ""
            cover: root.page?.cover ?? ""
        }

        MosaicArt {
            visible: root.kind === "playlist" || root.kind === "queue"
            size: 120
            covers: root.page?.covers ?? []
        }

        Column {
            id: details

            x: 140
            width: parent.width - x
            spacing: 4

            // Back, and what this is
            Row {
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "keyboard_arrow_left"
                    size: 18
                    color: Theme.on_surface_variant

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.back()
                    }
                }

                Label {
                    text: ({
                            album: "Album",
                            artist: "Artist",
                            playlist: "Playlist",
                            queue: "Playing next"
                        })[root.kind] ?? ""
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                }
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.page?.title ?? ""
                color: Theme.on_surface
                font.pixelSize: 22
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                visible: text !== ""
                text: root.page?.subtitle ?? ""
                color: Theme.on_surface_variant
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.page?.info ?? ""
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            // Its buttons: Play and Shuffle, or the queue's
            Row {
                topPadding: 8
                spacing: 8

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: button

                        required property var modelData

                        width: buttonLabel.implicitWidth + 52
                        height: 36
                        radius: 18
                        color: modelData.primary ? (buttonMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary) : (buttonMouse.containsMouse ? Qt.alpha(Theme.secondary_container, 0.8) : Theme.secondary_container)

                        Icon {
                            x: 14
                            name: button.modelData.icon
                            size: 18
                            color: button.modelData.primary ? Theme.on_primary : Theme.on_secondary_container
                        }

                        Label {
                            id: buttonLabel

                            x: 38
                            text: button.modelData.label
                            color: button.modelData.primary ? Theme.on_primary : Theme.on_secondary_container
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: buttonMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(button.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // An artist's albums, small, to open by a click
    ListView {
        id: albums

        anchors.top: header.bottom
        anchors.topMargin: 6
        width: parent.width
        height: visible ? 64 : 0
        visible: root.kind === "artist" && (root.page?.albums?.length ?? 0) > 1
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? root.page.albums : []

        delegate: Rectangle {
            id: chip

            required property var modelData

            width: chipText.implicitWidth + 64
            height: 56
            radius: Theme.radius
            color: chipMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

            AlbumArt {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                size: 44
                source: chip.modelData.cover ? `file://${chip.modelData.cover}` : ""
            }

            Label {
                id: chipText

                x: 58
                width: Math.min(implicitWidth, 200)
                text: chip.modelData.title
                color: Theme.on_surface
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            MouseArea {
                id: chipMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAlbum(chip.modelData)
            }
        }
    }

    SongList {
        id: songList

        anchors.top: albums.visible ? albums.bottom : header.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        width: parent.width
        songs: root.songs
        numbered: root.kind === "album"
        keepPick: root.kind === "playlist" || root.kind === "queue"
        // An album's songs need only their artist, and only where it isn't
        // the album's; an artist's, their album; the rest, both
        detail: s => root.kind === "artist" ? s.album : root.kind === "album" ? (s.artist !== root.page?.subtitle ? s.artist : "") : [s.artist, s.album].filter(x => x).join("  ·  ")
        onActivated: index => root.play(index)
    }

    Label {
        anchors.horizontalCenter: songList.horizontalCenter
        anchors.verticalCenter: undefined
        y: songList.y + 40
        visible: root.page !== null && root.songs.length === 0
        text: root.kind === "queue" ? "Nothing queued: Enter on a song plays it, a queues it" : "Nothing in it yet: p adds songs to it"
        color: Theme.on_surface_variant
        font.weight: Font.Normal
    }
}
