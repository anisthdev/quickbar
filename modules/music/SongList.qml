import QtQuick
import "../.."
import "../../components"

// Songs as the music menu lists them, grouped as the launcher's rows: 2
// apart, rounder at the ends, the pick's fill sliding between them over the
// rows' backgrounds. `numbered` shows track numbers in place of covers (an
// album's page), `detail` what goes under a title. With `keepPick` (a
// playlist's or the queue's page, whose songs change under it), the pick
// stays on its song as the list changes, or where it was if the song went.
ListView {
    id: list

    property var songs: []
    property bool numbered: false
    property bool keepPick: false
    // The pick's song and place, as last moved to; a new list resets the
    // index before it can be read
    property string keptFile
    property int keptIndex: 0
    property var seenSongs: null
    // A song's line under its title
    property var detail: s => [s.artist, s.album].filter(x => x).join("  ·  ")
    readonly property real rowHeight: 58

    // A double click, or Enter through the owner
    signal activated(int index)

    onCurrentIndexChanged: {
        if (songs !== seenSongs)
            return;
        keptFile = songs[currentIndex]?.file ?? "";
        keptIndex = currentIndex;
    }
    onSongsChanged: {
        if (!keepPick || seenSongs === null) {
            seenSongs = songs;
            return;
        }
        Qt.callLater(() => {
            const i = songs.findIndex(s => s.file === keptFile);
            seenSongs = songs;
            currentIndex = i >= 0 ? i : Math.max(0, Math.min(keptIndex, count - 1));
        });
    }

    model: songs
    spacing: 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Keeps the current row in view as the keys move it
    highlightRangeMode: ListView.ApplyRange
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightFollowsCurrentItem: false
    highlight: Rectangle {
        id: pickFill

        // Not to slide in from the top on opening
        property bool settled: false

        Component.onCompleted: Qt.callLater(() => settled = true)

        y: list.currentItem?.y ?? 0
        width: list.width
        height: list.rowHeight
        radius: Theme.radius
        color: Theme.secondary_container

        Behavior on y {
            enabled: pickFill.settled
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    delegate: SongRow {
        id: row

        required property var modelData
        required property int index

        width: list.width
        height: list.rowHeight
        song: modelData
        number: list.numbered ? (modelData.track || index + 1) : 0
        detail: list.detail(modelData)
        current: index === list.currentIndex
        playing: modelData.file === MpdPlayer.file
        onClicked: list.currentIndex = index
        onActivated: {
            list.currentIndex = index;
            list.activated(index);
        }

        // The row's background, under the list's highlight; it stays as the
        // pick slides over it
        Rectangle {
            parent: list.contentItem
            z: -1
            x: row.x
            y: row.y
            width: row.width
            height: row.height
            topLeftRadius: row.index === 0 ? Theme.radius : 3
            topRightRadius: row.index === 0 ? Theme.radius : 3
            bottomLeftRadius: row.index === list.count - 1 ? Theme.radius : 3
            bottomRightRadius: row.index === list.count - 1 ? Theme.radius : 3
            color: row.hovered && !row.current ? Theme.surface_container_highest : Theme.surface_container_high
        }
    }
}
