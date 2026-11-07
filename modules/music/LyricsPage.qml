import Quickshell
import Quickshell.Io
import QtQuick
import "../.."
import "../../components"

// A page in the music menu: the lyrics of the song mpd is playing, read
// through scripts/music-lyrics, following it from one song to the next, large,
// round and heavy, in a font for each script. Timed lyrics are for the line
// being sung: it stays in the middle, full size, the others fading with their
// distance from it; a click on a line goes there. Moving through them (the menu's keys,
// through `list`, or the wheel) lets them be read ahead, and they follow again
// after a moment. Plain lyrics only scroll.
Item {
    id: root

    readonly property var player: MpdPlayer
    readonly property string script: Quickshell.shellDir + "/scripts/music-lyrics"
    readonly property alias list: lines
    // On screen: nothing is read or followed otherwise
    property bool shown: false
    // { timed, lines: [{ time, text }] }, of the song `loaded`
    property var lyrics: ({
            timed: false,
            lines: []
        })
    property string loaded
    property bool reading: false
    // The line being sung, -1 before the first
    property int sung: -1
    // Moved by hand: stays put for a moment
    property bool browsing: false
    // Moving the list to the line, not by hand
    property bool placing: false
    readonly property bool timed: lyrics.timed

    signal back

    function read() {
        if (reader.running)
            return;
        reading = true;
        loaded = player.file;
        reader.running = loaded !== "";
        if (!reader.running) {
            reading = false;
            show({
                timed: false,
                lines: []
            });
        }
    }

    function show(found) {
        browsing = false;
        sung = -1;
        placing = true;
        lyrics = found;
        lines.currentIndex = found.lines.length > 0 ? 0 : -1;
        lines.positionViewAtBeginning();
        placing = false;
        follow();
    }

    // The last line started by now
    function lineAt(seconds) {
        const all = lyrics.lines;
        let low = 0, high = all.length;
        while (low < high) {
            const middle = (low + high) >> 1;
            if (all[middle].time <= seconds)
                low = middle + 1;
            else
                high = middle;
        }
        return low - 1;
    }

    // The font and size for a line, by its script, each as large as the next
    function typeOf(text) {
        if (/[\u0600-\u06ff]/.test(text))
            return {
                family: "Noto Nastaliq Urdu",
                size: 30
            };
        if (/[\u0900-\u097f]/.test(text))
            return {
                family: "Noto Sans Devanagari",
                size: 34
            };
        return {
            family: Theme.fontFamily,
            size: 36
        };
    }

    function place() {
        placing = true;
        lines.currentIndex = Math.max(0, sung);
        placing = false;
    }

    function follow() {
        if (!timed)
            return;
        const line = lineAt(player.exactElapsed());
        if (line !== sung) {
            sung = line;
            if (!browsing)
                place();
        }
    }

    function browse() {
        if (!timed)
            return;
        browsing = true;
        resume.restart();
    }

    // Enter on the pick, or a click on a line
    function seek(index) {
        const line = lyrics.lines[index];
        if (!timed || !line)
            return;
        browsing = false;
        resume.stop();
        player.mpc("seek", String(Math.floor(line.time)));
    }

    function seekPick() {
        seek(lines.currentIndex);
    }

    onShownChanged: {
        if (shown)
            read();
    }

    Connections {
        target: root.player

        function onFileChanged() {
            if (root.shown)
                root.read();
        }

        function onSyncAtChanged() {
            if (root.shown)
                root.follow();
        }
    }

    Process {
        id: reader

        command: [root.script, root.loaded]
        stdout: StdioCollector {
            onStreamFinished: {
                root.reading = false;
                // Skipped to another meanwhile
                if (root.loaded !== root.player.file) {
                    root.read();
                    return;
                }
                try {
                    root.show(JSON.parse(text));
                } catch (e) {
                    root.show({
                        timed: false,
                        lines: []
                    });
                }
            }
        }
    }

    Timer {
        interval: 100
        running: root.shown && root.timed && root.player.playing
        repeat: true
        onTriggered: root.follow()
    }

    Timer {
        id: resume

        interval: 4000
        onTriggered: {
            root.browsing = false;
            root.place();
        }
    }

    Item {
        id: header

        width: parent.width
        height: 22

        Icon {
            id: backIcon

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
            anchors.left: backIcon.right
            anchors.leftMargin: 6
            text: root.lyrics.lines.length > 0 && !root.timed ? "Lyrics, not timed" : "Lyrics"
            color: Theme.on_surface_variant
            font.pixelSize: 12
        }
    }

    ListView {
        id: lines

        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.lyrics.lines
        // The current line stays in the middle, sliding there, even the
        // first and the last
        header: Item {
            height: root.timed ? lines.height * 0.38 : 0
        }
        footer: Item {
            height: root.timed ? lines.height * 0.38 : 0
        }
        highlight: Item {}
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height / 2 - 60
        preferredHighlightEnd: height / 2 + 60
        highlightMoveDuration: Theme.animNormal * 2
        highlightMoveVelocity: -1
        onCurrentIndexChanged: {
            if (!root.placing)
                root.browse();
        }
        onMovementStarted: root.browse()
        onMovementEnded: root.browse()

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool sung: root.timed && index === root.sung
            readonly property bool picked: root.browsing && index === lines.currentIndex
            readonly property int distance: Math.abs(index - Math.max(0, root.sung))

            width: lines.width
            height: words.implicitHeight + 20
            radius: Theme.radius
            color: picked ? Theme.surface_container_highest : mouse.containsMouse && root.timed ? Theme.surface_container_high : "transparent"

            Label {
                id: words

                readonly property var type: root.typeOf(row.modelData.text)

                anchors.verticalCenter: parent.verticalCenter
                x: 14
                width: parent.width - 28
                text: row.modelData.text
                wrapMode: Text.WordWrap
                color: Theme.on_surface
                font.family: type.family
                font.pixelSize: root.timed ? type.size : type.size * 0.72
                font.weight: Font.ExtraBold
                roundness: 100
                transformOrigin: effectiveHorizontalAlignment === Text.AlignRight ? Item.Right : Item.Left
                // A size would rewrap as it changed
                scale: !root.timed || row.sung || row.index === 0 && root.sung < 0 ? 1 : 0.84
                opacity: !root.timed ? 1 : root.browsing ? 0.65 : [1, 0.42, 0.24][row.distance] ?? 0.13

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animNormal
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.timed ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.seek(row.index)
            }
        }
    }

    Label {
        anchors.centerIn: lines
        visible: lines.count === 0 && !root.reading
        text: root.player.active ? "No lyrics for this song" : "Nothing playing"
        color: Theme.on_surface_variant
        font.weight: Font.Normal
    }
}
