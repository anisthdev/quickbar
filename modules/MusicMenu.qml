import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."
import "../components"

// The music library as a menu, as ReelMenu is the video one, with two
// tabs: mpd's albums (scripts/music-library: one per folder, newest first)
// and its playlists, as a strip of covers across the middle of the screen,
// the album mpd is playing marked. Picking plays it through mpd from its
// first track, and the menu closes; the bar's now playing chip takes over.
// Its tracks open below the covers, to play from one in particular. What
// tunes downloads lands here. Playlists are mpd's own, so they work with
// mpc too: songs are added to them from here, and the queue saved as one.
//
// Keys: h/l (or j/k, the arrows) move, gg/G go to the first and last, Tab
// and Shift+Tab switch between albums and playlists, Enter or Space plays,
// a adds it to mpd's queue (the menu stays), o opens its tracks, p adds it
// to a playlist, S saves the queue as a new playlist, D twice deletes a
// playlist, q or Esc closes. In the tracks j/k (gg/G, Ctrl+d/u) move,
// Enter, Space or l plays from that track, a queues the track alone, p adds
// it to a playlist, h, o or Esc go back to the covers; in a playlist's,
// d removes the track and J/K move it down and up. / or i (or a click)
// focuses the filter: typing filters by title, artist or track title,
// Enter plays (from the track that matched, when it was a track), Esc goes
// back to the covers keeping the filter, and Esc there clears it. The
// picker for p and S filters the playlists as you type a name: Enter adds
// to the one picked, or makes a new one by that name; Esc cancels. The
// mouse wheel moves; a click picks, a click on the pick plays, a right
// click opens its tracks.
Scope {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/music-library"
    readonly property real coverSize: 240
    readonly property real grownScale: 1.08

    property bool open: false
    property bool filtering: false
    // The library, kept between openings, so it shows at once while it's
    // read again
    property var library: null
    // What the right of the header says for a moment, e.g. "Queued"
    property string flash
    // 0 albums, 1 playlists
    property int tab: 0
    // The current album's or playlist's tracks, open below the covers
    property bool tracksOpen: false
    // Just opened: a fresh read of the library starts from the first again
    property bool fresh: false
    // The playlist a first D asked to delete
    property string pendingDelete
    // The picker: "add" (pickFiles to a playlist) or "save" (the queue)
    property string picking
    property var pickFiles: []
    property string pickWhat
    // mpc commands changing playlists, run one after another
    property var edits: []

    // Both kinds alike: title, artist, cover, tracks, seconds
    readonly property var albums: (library?.albums ?? []).map(a => Object.assign({
            kind: "album",
            key: `a:${a.dir}`
        }, a))
    readonly property var playlists: (library?.playlists ?? []).map(p => ({
                kind: "playlist",
                key: `p:${p.name}`,
                name: p.name,
                title: p.name,
                artist: "",
                year: "",
                cover: p.covers[0] ?? "",
                covers: p.covers,
                tracks: p.tracks,
                seconds: p.seconds,
                missing: p.tracks.filter(t => t.missing).length
            }))
    // The playlists the picker offers for what's typed: a new one by that
    // name first, unless there is one
    readonly property var pickChoices: {
        if (picking !== "add")
            return [];
        const q = pickField.text.trim();
        const names = playlists.map(p => p.name).filter(n => n.toLowerCase().includes(q.toLowerCase()));
        const taken = playlists.some(p => p.name.toLowerCase() === q.toLowerCase());
        return (q && !taken ? [{
                    name: q,
                    fresh: true
                }] : []).concat(names.map(n => ({
                    name: n,
                    fresh: false
                })));
    }
    // The albums matching the filter, ranked as the launcher menus do: the
    // start of the title or artist, then the start of a word, then
    // anywhere; then the albums with a track whose title has it. Each with
    // that track's index, when it matched by a track.
    readonly property var matches: {
        const all = tab === 0 ? albums : playlists;
        const q = field.text.trim().toLowerCase();
        if (q === "")
            return all.map(album => ({
                        album,
                        hit: -1
                    }));
        const rank = album => {
            const text = `${album.title} ${album.artist}`.toLowerCase();
            if (album.title.toLowerCase().startsWith(q) || album.artist.toLowerCase().startsWith(q))
                return 0;
            if (text.split(/[\s\-_.:,()]+/).some(w => w.startsWith(q)))
                return 1;
            return text.includes(q) ? 2 : -1;
        };
        return all.map((album, i) => {
            const r = rank(album);
            const hit = r < 0 ? album.tracks.findIndex(t => t.title.toLowerCase().includes(q)) : -1;
            return {
                album,
                i,
                hit,
                r: r >= 0 ? r : hit >= 0 ? 3 : -1
            };
        }).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i);
    }
    readonly property var items: matches.map(m => m.album)
    readonly property var current: items[strip.currentIndex] ?? null
    // The track of the current album the filter found, or -1
    readonly property int currentHit: matches[strip.currentIndex]?.hit ?? -1

    function show() {
        fresh = true;
        reader.running = true;
        field.text = "";
        flash = "";
        picking = "";
        tracksOpen = false;
        strip.currentIndex = 0;
        open = true;
        stopFilter();
    }

    function startFilter() {
        filtering = true;
        field.forceActiveFocus();
    }

    function stopFilter() {
        filtering = false;
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    // "1 h 5 min", "42 min"
    function runtime(seconds) {
        const minutes = Math.round(seconds / 60);
        return minutes >= 60 ? `${Math.floor(minutes / 60)} h ${minutes % 60} min` : `${minutes} min`;
    }

    function switchTo(index) {
        tab = (index + 2) % 2;
        tracksOpen = false;
        pendingDelete = "";
        strip.currentIndex = 0;
        strip.positionViewAtBeginning();
    }

    // The album or playlist, from its first track, or from the track the
    // filter found
    function play(index) {
        playFrom(index, matches[index]?.hit ?? -1);
    }

    // The album or playlist in place of mpd's queue, from the track at
    // track (its first, if none). A playlist is loaded as mpd has it, which
    // leaves out its missing songs.
    function playFrom(index, track) {
        const item = items[index];
        if (!item)
            return;
        const from = Math.max(0, track);
        if (item.kind === "playlist") {
            const position = item.tracks.slice(0, from).filter(t => !t.missing).length + 1;
            if (item.tracks.every(t => t.missing))
                return say(`Nothing in ${item.name} to play`);
            Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play "$2"', "sh", item.name, String(position)]);
        } else {
            Quickshell.execDetached(["sh", "-c", 'n=$1; shift; mpc -q clear && mpc -q add "$@" && mpc -q play "$n"', "sh", String(from + 1), ...item.tracks.map(t => t.file)]);
        }
        hide();
    }

    // Its songs as files, without the missing ones
    function filesOf(item) {
        return (item?.tracks ?? []).filter(t => !t.missing).map(t => t.file);
    }

    // The album or playlist after what's queued
    function enqueue(index) {
        const item = items[index];
        if (!item || filesOf(item).length === 0)
            return;
        Quickshell.execDetached(item.kind === "playlist" ? ["mpc", "-q", "load", item.name] : ["mpc", "-q", "add", ...filesOf(item)]);
        say(`Queued ${item.title}`);
    }

    // One track of the current album or playlist after what's queued
    function enqueueTrack(track) {
        const t = current?.tracks[track];
        if (!t || t.missing)
            return;
        Quickshell.execDetached(["mpc", "-q", "add", t.file]);
        say(`Queued ${t.title}`);
    }

    function say(text) {
        flash = text;
        flashTimer.restart();
    }

    // The library as read, or as just changed, with the pick kept on the
    // same album or playlist and track
    function setLibrary(next) {
        const key = current?.key;
        const track = tracks.currentIndex;
        library = next;
        if (fresh) {
            fresh = false;
            strip.currentIndex = 0;
            return;
        }
        const i = items.findIndex(x => x.key === key);
        strip.currentIndex = i >= 0 ? i : Math.min(strip.currentIndex, items.length - 1);
        if (tracksOpen)
            tracks.currentIndex = Math.min(track, tracks.count - 1);
    }

    function run(command) {
        edits = edits.concat([command]);
        nextEdit();
    }

    function nextEdit() {
        if (editor.running || edits.length === 0)
            return;
        editor.command = edits[0];
        edits = edits.slice(1);
        editor.running = true;
    }

    // A playlist's tracks changed here at once, ahead of mpd
    function changePlaylist(name, change) {
        const next = Object.assign({}, library);
        next.playlists = library.playlists.map(p => p.name === name ? Object.assign({}, p, {
                    tracks: change(p.tracks.slice())
                }) : p);
        setLibrary(next);
    }

    function removeTrack(i) {
        const p = current;
        if (p?.kind !== "playlist" || !p.tracks[i])
            return;
        run(["mpc", "-q", "delplaylist", p.name, String(i + 1)]);
        changePlaylist(p.name, t => {
            t.splice(i, 1);
            return t;
        });
        tracks.currentIndex = Math.min(i, tracks.count - 1);
    }

    function moveTrack(i, by) {
        const p = current;
        const j = i + by;
        if (p?.kind !== "playlist" || j < 0 || j >= p.tracks.length)
            return;
        run(["mpc", "-q", "moveplaylist", p.name, String(i + 1), String(j + 1)]);
        changePlaylist(p.name, t => {
            t.splice(j, 0, t.splice(i, 1)[0]);
            return t;
        });
        tracks.currentIndex = j;
    }

    // D once asks, D again deletes
    function deletePlaylist() {
        const p = current;
        if (p?.kind !== "playlist")
            return;
        if (pendingDelete !== p.name) {
            say(`D again deletes ${p.name}`);
            pendingDelete = p.name;
            return;
        }
        pendingDelete = "";
        run(["mpc", "-q", "rm", p.name]);
        const next = Object.assign({}, library);
        next.playlists = library.playlists.filter(x => x.name !== p.name);
        setLibrary(next);
        say(`Deleted ${p.name}`);
    }

    // The picker, for files to add (named what in its title), or to save
    // the queue
    function startPick(mode, files, what) {
        if (mode === "add" && files.length === 0)
            return;
        picking = mode;
        pickFiles = files;
        pickWhat = what;
        pickField.text = "";
        pickList.currentIndex = 0;
        pickField.forceActiveFocus();
    }

    function stopPick() {
        picking = "";
        if (filtering)
            field.forceActiveFocus();
        else
            keys.forceActiveFocus();
    }

    function confirmPick() {
        const name = picking === "save" ? pickField.text.trim() : pickChoices[pickList.currentIndex]?.name ?? "";
        if (name === "")
            return;
        if (name.includes("/"))
            return say("A playlist's name can't have a /");
        if (picking === "save") {
            if (playlists.some(p => p.name === name))
                return say(`${name} is already a playlist`);
            run(["mpc", "-q", "save", name]);
            say(`Saved the queue as ${name}`);
        } else {
            // mpd makes the playlist if there isn't one
            run(["mpc", "-q", "addplaylist", name, ...pickFiles]);
            say(`Added ${pickWhat} to ${name}`);
        }
        stopPick();
    }

    // The current album's tracks, at the one the filter found
    function openTracks() {
        if (!current)
            return;
        tracksOpen = true;
        tracks.currentIndex = Math.max(0, currentHit);
        tracks.positionViewAtIndex(tracks.currentIndex, ListView.Contain);
    }

    // "3:05"
    function clock(seconds) {
        return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
    }

    Process {
        id: reader

        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.setLibrary(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    // The edits, in order; the library read again once they're through
    Process {
        id: editor

        onExited: {
            if (root.edits.length > 0)
                root.nextEdit();
            else
                reader.running = true;
        }
    }

    Timer {
        id: flashTimer

        interval: 2500
        onTriggered: {
            root.flash = "";
            root.pendingDelete = "";
        }
    }

    PanelWindow {
        id: window

        property real reveal: 0
        // The pick grows once the panel has sprung open
        property bool settled: false

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished
        visible: false
        // Blurred, without Hyprland's layer slide (see looknfeel.lua)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    closeAnim.stop();
                    window.settled = false;
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    window.settled = false;
                    closeAnim.restart();
                }
            }
        }

        NumberAnimation {
            id: openAnim

            target: window
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
            onFinished: window.settled = true
        }

        NumberAnimation {
            id: closeAnim

            target: window
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
            onFinished: window.visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            // The tracks' room, opening and closing with them
            property real tracksHeight: root.tracksOpen ? tracks.height + 14 : 0
            readonly property real fullHeight: strip.y + strip.height + 20 + tracksHeight

            Behavior on tracksHeight {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            // Edge to edge across the middle of the screen, square; it
            // opens out from its centre line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(0, fullHeight * window.reveal)
            color: Theme.surface_container
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keys

                // The first g of a gg
                property bool pendingG: false

                Timer {
                    id: gTimer

                    interval: 600
                    onTriggered: keys.pendingG = false
                }

                Keys.onPressed: event => {
                    if (root.tracksOpen) {
                        event.accepted = trackKey(event);
                        return;
                    }
                    const g = event.key === Qt.Key_G && event.text === "g";
                    if (!g)
                        pendingG = false;
                    if (event.key !== Qt.Key_D)
                        root.pendingDelete = "";
                    switch (event.key) {
                    case Qt.Key_O:
                        root.openTracks();
                        break;
                    case Qt.Key_Tab:
                        root.switchTo(root.tab + 1);
                        break;
                    case Qt.Key_Backtab:
                        root.switchTo(root.tab - 1);
                        break;
                    case Qt.Key_P:
                        root.startPick("add", root.filesOf(root.current), root.current?.title ?? "");
                        break;
                    case Qt.Key_S:
                        if (event.text === "S")
                            root.startPick("save", [], "");
                        break;
                    case Qt.Key_D:
                        if (event.text === "D")
                            root.deletePlaylist();
                        break;
                    case Qt.Key_H:
                    case Qt.Key_K:
                    case Qt.Key_Left:
                    case Qt.Key_Up:
                        strip.decrementCurrentIndex();
                        break;
                    case Qt.Key_L:
                    case Qt.Key_J:
                    case Qt.Key_Right:
                    case Qt.Key_Down:
                        strip.incrementCurrentIndex();
                        break;
                    case Qt.Key_G:
                        // A capital can come without Shift held (wtype)
                        if (event.text === "G") {
                            strip.currentIndex = strip.count - 1;
                        } else if (pendingG) {
                            pendingG = false;
                            strip.currentIndex = 0;
                        } else {
                            pendingG = true;
                            gTimer.restart();
                        }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.play(strip.currentIndex);
                        break;
                    case Qt.Key_A:
                        root.enqueue(strip.currentIndex);
                        break;
                    case Qt.Key_Slash:
                    case Qt.Key_I:
                        root.startFilter();
                        break;
                    case Qt.Key_Escape:
                        // A filter left on goes first
                        if (field.text !== "")
                            field.text = "";
                        else
                            root.hide();
                        break;
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                // The keys while the tracks are open
                function trackKey(event) {
                    const playlist = root.current?.kind === "playlist";
                    // J and K move a playlist's track, before ListKeys takes
                    // them as j and k
                    if (playlist && (event.text === "J" || event.text === "K")) {
                        root.moveTrack(tracks.currentIndex, event.text === "J" ? 1 : -1);
                        return true;
                    }
                    if (trackKeys.handle(event))
                        return true;
                    switch (event.key) {
                    case Qt.Key_D:
                        if (playlist && event.text === "d")
                            root.removeTrack(tracks.currentIndex);
                        break;
                    case Qt.Key_P: {
                        const t = root.current?.tracks[tracks.currentIndex];
                        if (t && !t.missing)
                            root.startPick("add", [t.file], t.title);
                        break;
                    }
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                    case Qt.Key_L:
                        root.playFrom(strip.currentIndex, tracks.currentIndex);
                        break;
                    case Qt.Key_A:
                        root.enqueueTrack(tracks.currentIndex);
                        break;
                    case Qt.Key_H:
                    case Qt.Key_O:
                    case Qt.Key_Escape:
                        root.tracksOpen = false;
                        break;
                    case Qt.Key_Slash:
                    case Qt.Key_I:
                        root.tracksOpen = false;
                        root.startFilter();
                        break;
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return false;
                    }
                    return true;
                }
            }

            ListKeys {
                id: trackKeys

                list: tracks
            }

            // The title and the filter
            Row {
                id: header

                x: 20
                y: 22
                height: 34
                spacing: 18

                Label {
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: "Music"
                    color: Theme.primary
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }

                // Albums and playlists, Tab between them
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: ["Albums", "Playlists"]

                        delegate: Rectangle {
                            id: chip

                            required property string modelData
                            required property int index
                            readonly property bool on: index === root.tab

                            width: chipLabel.implicitWidth + 28
                            height: 34
                            radius: 17
                            color: on ? Theme.secondary_container : Theme.surface_container_high

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            Label {
                                id: chipLabel

                                anchors.centerIn: parent
                                text: chip.modelData
                                color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchTo(chip.index)
                            }
                        }
                    }
                }

                // The filter, outlined while typing into it
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 300
                    height: 34
                    radius: 17
                    color: Theme.surface_container_highest
                    border.width: root.filtering ? 2 : 0
                    border.color: Theme.primary

                    // A click focuses it, as / does
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: root.startFilter()
                    }

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: 18
                        color: Theme.on_surface_variant
                    }

                    TextInput {
                        id: field

                        anchors.left: parent.left
                        anchors.leftMargin: 38
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.on_surface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        clip: true
                        onTextChanged: {
                            root.tracksOpen = false;
                            strip.currentIndex = 0;
                            strip.positionViewAtBeginning();
                        }

                        // Typing filters; these move and leave
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.stopFilter();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.play(strip.currentIndex);
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                strip.incrementCurrentIndex();
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                strip.decrementCurrentIndex();
                                break;
                            case Qt.Key_L:
                            case Qt.Key_J:
                            case Qt.Key_N:
                                if (!ctrl)
                                    return;
                                strip.incrementCurrentIndex();
                                break;
                            case Qt.Key_H:
                            case Qt.Key_K:
                            case Qt.Key_P:
                                if (!ctrl)
                                    return;
                                strip.decrementCurrentIndex();
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Label {
                        anchors.left: field.left
                        visible: field.text === ""
                        text: "Filter"
                        color: Theme.on_surface_variant
                        font.pixelSize: 15
                        font.weight: Font.Normal
                    }
                }
            }

            // The pick's details: year, tracks, length; or what was just done
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: header.verticalCenter
                text: {
                    if (root.flash)
                        return root.flash;
                    const a = root.current;
                    if (!a)
                        return "";
                    const count = a.tracks.length === 1 ? "1 track" : `${a.tracks.length} tracks`;
                    return [a.year, count, a.seconds ? root.runtime(a.seconds) : "", a.missing ? `${a.missing} missing` : ""].filter(b => b).join("  ·  ");
                }
                color: root.flash ? Theme.primary : Theme.on_surface_variant
                font.pixelSize: 15
            }

            ListView {
                id: strip

                // A card: the cover with room above for it to grow, then
                // two lines
                readonly property real cardHeight: root.coverSize * root.grownScale + 12 + 52

                y: header.y + header.height + 12
                width: parent.width
                height: cardHeight
                orientation: ListView.Horizontal
                interactive: false
                spacing: 22
                leftMargin: 32
                rightMargin: 32
                model: root.items
                highlightFollowsCurrentItem: true
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width * 0.25
                preferredHighlightEnd: width * 0.75
                highlightMoveDuration: 280
                highlight: Item {}

                WheelHandler {
                    onWheel: event => {
                        if (event.angleDelta.y + event.angleDelta.x > 0)
                            strip.decrementCurrentIndex();
                        else
                            strip.incrementCurrentIndex();
                    }
                }

                delegate: Item {
                    id: card

                    required property var modelData
                    required property int index
                    readonly property var album: modelData
                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property bool grown: isCurrent && window.settled
                    readonly property bool playing: album.kind === "album" && root.library?.playing === album.dir

                    width: root.coverSize
                    height: strip.cardHeight

                    // Grows upward, clear of the title below
                    Item {
                        id: cover

                        anchors.bottom: lines.top
                        anchors.bottomMargin: 12
                        width: root.coverSize
                        height: root.coverSize
                        transformOrigin: Item.Bottom
                        z: 1
                        scale: card.grown ? root.grownScale : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            radius: frame.radius
                            blur: 24
                            offset.y: 4
                            color: Qt.rgba(0, 0, 0, 0.35)
                            opacity: card.grown ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animNormal
                                }
                            }
                        }

                        ClippingRectangle {
                            id: frame

                            anchors.fill: parent
                            radius: 14
                            color: Theme.primary_container

                            // No cover: a note, in its place
                            Icon {
                                anchors.centerIn: parent
                                visible: !card.album.cover
                                name: "media_music_note"
                                size: root.coverSize * 0.4
                                color: Theme.on_primary_container
                            }

                            Image {
                                anchors.fill: parent
                                visible: (card.album.covers?.length ?? 0) < 4
                                source: card.album.cover ? "file://" + card.album.cover : ""
                                sourceSize.width: root.coverSize * 2
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                            }

                            // A playlist of four albums or more: their
                            // covers, two by two
                            Grid {
                                anchors.fill: parent
                                visible: (card.album.covers?.length ?? 0) >= 4
                                columns: 2

                                Repeater {
                                    model: visible ? card.album.covers : []

                                    Image {
                                        required property string modelData

                                        width: root.coverSize / 2
                                        height: root.coverSize / 2
                                        source: "file://" + modelData
                                        sourceSize.width: root.coverSize
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                            }

                            // The rest sit back
                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: card.isCurrent ? 0 : 0.4

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animNormal
                                    }
                                }
                            }
                        }

                        // Playing: a chip in the corner, with the equalizer
                        Rectangle {
                            visible: card.playing
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: playingRow.implicitWidth + 18
                            height: 26
                            radius: 13
                            // Solid, to read on any picture
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)
                            opacity: card.isCurrent ? 1 : 0.7

                            Row {
                                id: playingRow

                                anchors.centerIn: parent
                                spacing: 4

                                Icon {
                                    name: "media_music_note"
                                    size: 16
                                    color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                                }

                                Label {
                                    text: "Playing"
                                    color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                                    font.pixelSize: 12
                                    font.weight: Theme.titleWeight
                                }
                            }
                        }
                    }

                    Column {
                        id: lines

                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 52
                        spacing: 2

                        Label {
                            anchors.verticalCenter: undefined
                            width: parent.width
                            text: card.album.title
                            elide: Text.ElideRight
                            color: card.isCurrent ? Theme.on_surface : Theme.on_surface_variant
                            font.pixelSize: 16
                            font.weight: Theme.titleWeight
                        }

                        // The artist, or the track the filter found
                        Label {
                            readonly property int hit: root.matches[card.index]?.hit ?? -1

                            anchors.verticalCenter: undefined
                            width: parent.width
                            text: {
                                const a = card.album;
                                if (hit >= 0)
                                    return `♪ ${a.tracks[hit].title}`;
                                if (a.kind === "playlist")
                                    return a.tracks.length === 1 ? "1 track" : `${a.tracks.length} tracks`;
                                return a.artist;
                            }
                            elide: Text.ElideRight
                            color: card.isCurrent ? Theme.primary : Theme.on_surface_variant
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                strip.currentIndex = card.index;
                                root.openTracks();
                            } else if (card.isCurrent) {
                                root.play(card.index);
                            } else {
                                strip.currentIndex = card.index;
                            }
                        }
                    }
                }
            }

            // The current album's tracks, while open
            ListView {
                id: tracks

                readonly property real rowHeight: 44
                readonly property int shownRows: Math.min(count, 8)

                x: 32
                y: strip.y + strip.height + 14
                width: parent.width - 64
                height: shownRows * rowHeight + Math.max(0, shownRows - 1) * spacing
                visible: root.tracksOpen || panel.tracksHeight > 0
                opacity: root.tracksOpen ? 1 : 0
                spacing: 2
                clip: true
                model: root.current?.tracks ?? []
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 180
                highlightMoveVelocity: -1
                highlight: Rectangle {
                    radius: Theme.radius
                    color: Theme.secondary_container
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }

                delegate: Item {
                    id: trackRow

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property bool playing: root.library?.playing_file === modelData.file
                    readonly property bool first: index === 0
                    readonly property bool last: index === tracks.count - 1

                    width: tracks.width
                    height: tracks.rowHeight

                    // The row's background, under the sliding highlight
                    Rectangle {
                        parent: tracks.contentItem
                        z: -1
                        x: trackRow.x
                        y: trackRow.y
                        width: trackRow.width
                        height: trackRow.height
                        topLeftRadius: trackRow.first ? Theme.radius : 3
                        topRightRadius: trackRow.first ? Theme.radius : 3
                        bottomLeftRadius: trackRow.last ? Theme.radius : 3
                        bottomRightRadius: trackRow.last ? Theme.radius : 3
                        color: Theme.surface_container_high
                    }

                    // The number, or the equalizer on the one playing
                    Item {
                        id: number

                        x: 12
                        width: 28
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            visible: !trackRow.playing
                            // A playlist's own order; an album's numbers
                            text: root.current?.kind === "playlist" ? trackRow.index + 1 : trackRow.modelData.track || trackRow.index + 1
                            color: Theme.on_surface_variant
                            font.family: Theme.monoFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        Equalizer {
                            anchors.centerIn: parent
                            visible: trackRow.playing
                            playing: true
                            color: Theme.primary
                        }
                    }

                    Label {
                        anchors.left: number.right
                        anchors.leftMargin: 12
                        anchors.right: length.left
                        anchors.rightMargin: 16
                        text: {
                            const t = trackRow.modelData;
                            // A featured artist, say, when not the album's
                            const other = t.artist && t.artist !== root.current?.artist ? `  ·  ${t.artist}` : "";
                            return t.title + other;
                        }
                        elide: Text.ElideRight
                        color: trackRow.playing ? Theme.primary : trackRow.modelData.missing ? Theme.outline : Theme.on_surface
                        font.pixelSize: 15
                    }

                    Text {
                        id: length

                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: trackRow.modelData.missing ? "Missing" : root.clock(trackRow.modelData.seconds)
                        color: Theme.on_surface_variant
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playFrom(strip.currentIndex, trackRow.index)
                    }
                }
            }

            Label {
                anchors.verticalCenter: undefined
                anchors.centerIn: strip
                visible: root.items.length === 0
                text: {
                    if (!root.library)
                        return "Loading the library…";
                    if (field.text.trim() !== "")
                        return root.tab === 0 ? "No album matches" : "No playlist matches";
                    return root.tab === 0 ? "No music yet: Entertainment → Music finds some" : "No playlists yet: p adds an album or a track to one, S saves the queue as one";
                }
                color: Theme.on_surface_variant
                font.pixelSize: 20
            }
        }

        // The picker for p and S, above the panel: a name, and for adding,
        // the playlists matching it
        Rectangle {
            id: picker

            readonly property int shownRows: Math.min(pickList.count, 6)

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: panel.top
            anchors.bottomMargin: 14
            width: 440
            height: pickColumn.implicitHeight + 36
            visible: root.picking !== "" && root.open
            radius: Theme.cardRadius
            color: Theme.surface_container

            // Swallow clicks on it
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: pickColumn

                x: 18
                y: 18
                width: parent.width - 36
                spacing: 12

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: root.picking === "save" ? "Save the queue as" : `Add ${root.pickWhat} to`
                    elide: Text.ElideRight
                    color: Theme.primary
                    font.pixelSize: 20
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.radius
                    color: Theme.surface_container_highest
                    border.width: 2
                    border.color: Theme.primary

                    TextInput {
                        id: pickField

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.on_surface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        clip: true
                        onTextChanged: pickList.currentIndex = 0

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.stopPick();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.confirmPick();
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                pickList.incrementCurrentIndex();
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                pickList.decrementCurrentIndex();
                                break;
                            case Qt.Key_J:
                            case Qt.Key_N:
                                if (!ctrl)
                                    return;
                                pickList.incrementCurrentIndex();
                                break;
                            case Qt.Key_K:
                            case Qt.Key_P:
                                if (!ctrl)
                                    return;
                                pickList.decrementCurrentIndex();
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }

                    Label {
                        anchors.left: pickField.left
                        visible: pickField.text === ""
                        text: root.picking === "save" ? "Name the playlist" : "A playlist, or a new one's name"
                        color: Theme.on_surface_variant
                        font.pixelSize: 15
                        font.weight: Font.Normal
                    }
                }

                ListView {
                    id: pickList

                    readonly property real rowHeight: 40

                    visible: count > 0
                    width: parent.width
                    height: picker.shownRows * rowHeight + Math.max(0, picker.shownRows - 1) * spacing
                    spacing: 2
                    clip: true
                    model: root.pickChoices
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 150
                    highlightMoveVelocity: -1
                    highlight: Rectangle {
                        radius: Theme.radius
                        color: Theme.secondary_container
                    }

                    delegate: Item {
                        id: choice

                        required property var modelData
                        required property int index

                        width: pickList.width
                        height: pickList.rowHeight

                        Icon {
                            id: choiceIcon

                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: choice.modelData.fresh ? "edit" : "media_music_note"
                            size: 18
                            color: Theme.on_surface_variant
                        }

                        Label {
                            anchors.left: choiceIcon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            text: choice.modelData.fresh ? `New playlist “${choice.modelData.name}”` : choice.modelData.name
                            elide: Text.ElideRight
                            color: Theme.on_surface
                            font.pixelSize: 15
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pickList.currentIndex = choice.index;
                                root.confirmPick();
                            }
                        }
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call musicmenu toggle`, e.g. from Super+Shift+M
    IpcHandler {
        target: "musicmenu"

        function toggle(): void {
            root.toggle();
        }
    }
}
