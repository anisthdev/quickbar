import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The video library, in mpv's start screen's place: reel
// (~/Projects/reel) keeps ~/.cache/reel/library.json (titles, episodes,
// TMDB details and pictures), mpv keeps the progress (its watch_later files
// and watch history, read by scripts/watch-progress), and this shows them,
// full screen in a window of its own. mpv plays: a movie resumes where it
// stopped; a series plays from the picked episode on, the rest queued.
//
// Home: the picked title large at the top (backdrop, details, how far it's
// been watched), rows under it: Continue watching, then reel's rows,
// recently played first. A series opens its page: its episodes, season by
// season, starting at the one to watch next.
//
// Keys, vim style: h/l (or the arrows) move along a row, j/k between rows,
// gg/G to the first and last, Enter plays (or opens a series), q closes.
// On a series page h/l move through the episodes, [ and ] go a season back
// or on, Enter plays, and Esc, Backspace or H goes back home.
Scope {
    id: root

    readonly property string cache: Quickshell.env("HOME") + "/.cache/reel"
    readonly property string reel: Quickshell.env("HOME") + "/Projects/reel"

    property bool open: false
    // "home", or "series" for root.seriesId's page
    property string page: "home"
    property string seriesId: ""

    property var library: null
    property var progress: ({
            resume: {},
            played: {}
        })

    // Home's pick: the row, and each row's column by name (kept across
    // refreshes)
    property int row: 0
    property var cols: ({})
    // The series page's pick, an index into its episodes
    property int episode: 0

    // library.json with progress worked in, and the rows to show
    readonly property var model: build(library, progress)
    readonly property var rows: model.rows
    readonly property var currentRow: rows[Math.min(row, rows.length - 1)] ?? null
    readonly property var current: currentRow ? currentRow.items[colOf(currentRow.name)] ?? null : null
    readonly property var series: model.items.find(i => i.id === seriesId) ?? null
    readonly property var currentEpisode: series?.episodes[episode] ?? null
    readonly property var seasons: series ? [...new Set(series.episodes.map(e => e.season))] : []

    function toggle() {
        open ? hide() : show();
    }

    function show() {
        open = true;
        load();
    }

    // Progress read again, and reel rescans; library.json changes only
    // when something did. The menu (ReelMenu) calls it too
    function load() {
        refresh();
        scan.running = true;
    }

    function hide() {
        open = false;
    }

    function refresh() {
        progressRead.running = true;
    }

    // Close enough to the end to count as watched: credits, an anime ED,
    // a stop just before the end
    function finished(position, duration) {
        return duration > 0 && duration - position <= Math.max(90, duration * 0.05);
    }

    function build(lib, prog) {
        if (!lib)
            return {
                items: [],
                rows: []
            };
        const playedAt = (path, resume) => Math.max(prog.played[path] ?? 0, resume ? resume[1] : 0);
        const items = lib.items.map(src => {
            const item = Object.assign({}, src);
            // Played to the end, mpv drops the resume file: played with
            // none left means watched
            if (item.kind === "movie") {
                const resume = prog.resume[item.watch_later];
                item.lastPlayed = playedAt(item.path, resume);
                item.watched = resume ? finished(resume[0], item.duration) : item.lastPlayed > 0;
                item.position = resume && !item.watched ? resume[0] : 0;
                item.progress = item.duration ? item.position / item.duration : 0;
                return item;
            }
            item.lastPlayed = 0;
            let latest = -1;
            item.episodes = src.episodes.map((e, i) => {
                const ep = Object.assign({}, e);
                const resume = prog.resume[ep.watch_later];
                ep.lastPlayed = playedAt(ep.path, resume);
                ep.watched = resume ? finished(resume[0], ep.duration) : ep.lastPlayed > 0;
                ep.position = resume && !ep.watched ? resume[0] : 0;
                ep.progress = ep.duration ? ep.position / ep.duration : 0;
                if (ep.lastPlayed > item.lastPlayed) {
                    item.lastPlayed = ep.lastPlayed;
                    latest = i;
                }
                return ep;
            });
            // Next: the latest played, or the one after it if that's done
            item.next = latest < 0 ? -1 : item.episodes[latest].position > 0 ? latest : latest + 1;
            if (item.next >= item.episodes.length)
                item.next = -1;
            const next = item.episodes[item.next];
            item.progress = next ? next.progress : 0;
            return item;
        });
        const byRecent = (a, b) => b.lastPlayed - a.lastPlayed || a.title.localeCompare(b.title);
        const rows = [];
        const going = items.filter(i => i.lastPlayed > 0 && (i.kind === "movie" ? i.position > 0 : i.next >= 0)).sort(byRecent);
        if (going.length > 0)
            rows.push({
                name: "Continue watching",
                wide: true,
                items: going
            });
        for (const name of lib.rows) {
            const inRow = items.filter(i => i.category === name).sort(byRecent);
            if (inRow.length > 0)
                rows.push({
                    name,
                    wide: false,
                    items: inRow
                });
        }
        return {
            items,
            rows
        };
    }

    // Where the mouse last was, on screen. Cards follow it only when it
    // moves: cards sliding under a still pointer (rows scrolling) mustn't
    // take the pick from the keys
    property point pointer: Qt.point(-1, -1)

    function pointed(area, mouse) {
        const at = area.mapToGlobal(mouse.x, mouse.y);
        if (at.x === pointer.x && at.y === pointer.y)
            return false;
        pointer = at;
        return true;
    }

    function colOf(name) {
        return cols[name] ?? 0;
    }

    function setCol(name, index) {
        const c = Object.assign({}, cols);
        c[name] = index;
        cols = c;
    }

    function move(dx, dy) {
        if (page === "series") {
            if (series)
                episode = Math.max(0, Math.min(series.episodes.length - 1, episode + dx));
            return;
        }
        if (dy !== 0) {
            row = Math.max(0, Math.min(rows.length - 1, row + dy));
        } else if (currentRow) {
            setCol(currentRow.name, Math.max(0, Math.min(currentRow.items.length - 1, colOf(currentRow.name) + dx)));
        }
    }

    function ends(last) {
        if (page === "series") {
            if (series)
                episode = last ? series.episodes.length - 1 : 0;
        } else {
            row = last ? rows.length - 1 : 0;
        }
    }

    function season(step) {
        if (!series || !currentEpisode)
            return;
        const at = seasons.indexOf(currentEpisode.season) + step;
        if (at < 0 || at >= seasons.length)
            return;
        episode = series.episodes.findIndex(e => e.season === seasons[at]);
    }

    function activate() {
        if (page === "series") {
            if (series)
                play(series, episode);
            return;
        }
        if (!current)
            return;
        if (current.kind === "movie") {
            play(current, 0);
        } else {
            seriesId = current.id;
            // Where to carry on: the next episode, else the first
            episode = Math.max(0, current.next);
            page = "series";
        }
    }

    function back() {
        page = "home";
    }

    // A movie resumes by itself (mpv's watch_later); a series queues every
    // episode, from the picked one on, so next and previous move between them
    function play(item, index) {
        const paths = item.kind === "movie" ? [item.path] : item.episodes.map(e => e.path);
        player.createObject(root, {
            command: ["uwsm", "app", "--", "mpv", "--player-operation-mode=pseudo-gui", `--playlist-start=${item.kind === "movie" ? 0 : index}`, "--"].concat(paths)
        });
    }

    function runtime(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function left(item) {
        return `${runtime(item.duration - item.position)} left`;
    }

    function quality(item) {
        const w = item.width ?? 0, h = item.height ?? 0;
        return w >= 3200 || h >= 2000 ? "4K" : w >= 1800 || h >= 1000 ? "1080p" : w >= 1200 || h >= 700 ? "720p" : h > 0 ? "SD" : "";
    }

    function code(ep) {
        return `S${String(ep.season).padStart(2, "0")}E${String(ep.episode).padStart(2, "0")}`;
    }

    FileView {
        path: root.cache + "/library.json"
        watchChanges: true
        printErrors: false
        blockLoading: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.library = JSON.parse(text());
            } catch (e) {}
        }
    }

    Process {
        id: progressRead

        command: [Quickshell.shellDir + "/scripts/watch-progress"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.progress = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: scan

        command: [root.reel + "/scan.py"]
    }

    // One per playback; when mpv closes, the progress is read again
    Component {
        id: player

        Process {
            running: true
            onExited: {
                root.refresh();
                destroy();
            }
        }
    }

    FloatingWindow {
        id: window

        // Hyprland makes it full screen (windows.lua)
        title: "Reel"
        visible: root.open
        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
        onVisibleChanged: {
            root.open = visible;
            if (visible)
                keys.forceActiveFocus();
        }

        readonly property color base: color
        // What the top shows: the pick at home, the series on its page
        readonly property var hero: root.page === "series" ? root.series : root.current

        Item {
            id: keys

            anchors.fill: parent
            focus: true

            // The first g of a gg
            property bool pendingG: false

            Timer {
                id: gTimer

                interval: 600
                onTriggered: keys.pendingG = false
            }

            Keys.onPressed: event => {
                const g = event.key === Qt.Key_G && event.text === "g";
                if (!g)
                    pendingG = false;
                switch (event.key) {
                case Qt.Key_H:
                    // H, on a series page: home
                    if (event.text === "H" && root.page === "series") {
                        root.back();
                        break;
                    }
                // fallthrough
                case Qt.Key_Left:
                    root.move(-1, 0);
                    break;
                case Qt.Key_L:
                case Qt.Key_Right:
                    root.move(1, 0);
                    break;
                case Qt.Key_J:
                case Qt.Key_Down:
                    root.move(0, 1);
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    root.move(0, -1);
                    break;
                case Qt.Key_G:
                    if (event.text === "G") {
                        root.ends(true);
                    } else if (pendingG) {
                        pendingG = false;
                        root.ends(false);
                    } else {
                        pendingG = true;
                        gTimer.restart();
                    }
                    break;
                case Qt.Key_BracketLeft:
                    root.season(-1);
                    break;
                case Qt.Key_BracketRight:
                    root.season(1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.activate();
                    break;
                case Qt.Key_Escape:
                case Qt.Key_Backspace:
                    if (root.page === "series")
                        root.back();
                    else if (event.key === Qt.Key_Escape)
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

            // The backdrop, right and top, fading into the page; the next
            // one fades in over the last
            Item {
                id: backdrop

                property string source: window.hero?.backdrop ?? ""

                anchors.top: parent.top
                anchors.right: parent.right
                width: parent.width * 0.7
                height: parent.height * 0.68

                onSourceChanged: {
                    const next = front.visibleImage === a ? b : a;
                    next.source = source ? "file://" + source : "";
                    front.visibleImage = next;
                }

                QtObject {
                    id: front

                    property var visibleImage: a
                }

                Image {
                    id: a

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1280
                    asynchronous: true
                    opacity: front.visibleImage === a && status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                        }
                    }
                }

                Image {
                    id: b

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1280
                    asynchronous: true
                    opacity: front.visibleImage === b && status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                        }
                    }
                }

                // Fades: into the page on the left, and below
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: window.base
                        }
                        GradientStop {
                            position: 0.45
                            color: Qt.rgba(window.base.r, window.base.g, window.base.b, 0.55)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.4
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: window.base
                        }
                    }
                }
            }

            // The pick: what it is, and how far it's been watched
            Column {
                id: details

                readonly property var item: window.hero
                readonly property var ep: root.page === "series" ? root.currentEpisode : null

                x: 72
                y: parent.height * 0.1
                width: Math.min(720, parent.width * 0.42)
                spacing: 12

                Label {
                    anchors.verticalCenter: undefined
                    text: details.ep ? details.item?.title ?? "" : details.item?.category ?? ""
                    color: Theme.primary
                    font.pixelSize: 16
                    font.weight: Theme.titleWeight
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: details.ep ? details.ep.title || root.code(details.ep) : details.item?.title ?? ""
                    color: Theme.on_surface
                    font.pixelSize: 52
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                }

                // Year · rating · length · quality
                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    text: {
                        const i = details.item, e = details.ep;
                        if (!i)
                            return "";
                        const bits = [];
                        if (e) {
                            bits.push(root.code(e));
                            if (e.air_date)
                                bits.push(e.air_date.slice(0, 4));
                            if (e.duration)
                                bits.push(root.runtime(e.duration));
                            bits.push(root.quality(e));
                        } else {
                            if (i.year)
                                bits.push(i.year);
                            if (i.rating)
                                bits.push(`★ ${i.rating.toFixed(1)}`);
                            if (i.kind === "movie" && i.duration)
                                bits.push(root.runtime(i.duration));
                            if (i.kind === "series")
                                bits.push(`${i.episodes.length} episodes`);
                            if (i.kind === "movie")
                                bits.push(root.quality(i));
                        }
                        if ((e ?? i).watched && !(e ?? i).position)
                            bits.push("Watched");
                        return bits.filter(b => b !== "").join("  ·  ");
                    }
                    color: Theme.on_surface_variant
                    font.pixelSize: 17
                }

                Label {
                    anchors.verticalCenter: undefined
                    visible: !details.ep && (details.item?.genres?.length ?? 0) > 0
                    text: (details.item?.genres ?? []).join(", ")
                    color: Theme.on_surface_variant
                    font.pixelSize: 15
                }

                Label {
                    anchors.verticalCenter: undefined
                    width: parent.width
                    topPadding: 4
                    text: (details.ep ? details.ep.overview : details.item?.overview) ?? ""
                    color: Theme.on_surface
                    font.pixelSize: 17
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    lineHeight: 1.1
                }

                // How far: a bar and what's left, or the episode to carry on with
                Row {
                    readonly property var at: details.ep ?? (details.item?.kind === "movie" ? details.item : details.item?.episodes?.[details.item.next] ?? null)

                    visible: !!at && at.position > 0
                    spacing: 14
                    topPadding: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        height: 6
                        radius: 3
                        color: Theme.surface_container_highest

                        Rectangle {
                            width: parent.width * Math.min(1, parent.parent.at?.progress ?? 0)
                            height: parent.height
                            radius: 3
                            color: Theme.primary
                        }
                    }

                    Label {
                        text: {
                            const at = parent.at;
                            if (!at)
                                return "";
                            const where = !details.ep && details.item?.kind === "series" ? `${root.code(at)}  ·  ` : "";
                            return where + root.left(at);
                        }
                        color: Theme.on_surface_variant
                        font.pixelSize: 15
                    }
                }
            }

            // Home: the rows
            ListView {
                id: rowsView

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.44
                clip: true
                interactive: false
                spacing: 8
                model: root.rows
                currentIndex: root.row
                highlightFollowsCurrentItem: true
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: 40
                highlightMoveDuration: 320
                highlight: Item {}
                visible: opacity > 0
                opacity: root.page === "home" ? 1 : 0
                transform: Translate {
                    y: root.page === "home" ? 0 : 60

                    Behavior on y {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.emphasizedDecel
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }
                }

                delegate: Column {
                    id: rowItem

                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.row

                    width: rowsView.width
                    spacing: 6

                    Label {
                        anchors.verticalCenter: undefined
                        x: 72
                        text: rowItem.modelData.name
                        color: rowItem.active ? Theme.on_surface : Theme.on_surface_variant
                        font.pixelSize: 20
                        font.weight: Theme.titleWeight
                    }

                    ListView {
                        id: cards

                        width: parent.width
                        height: (rowItem.modelData.wide ? 180 : 225) * 1.1 + 24
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: 22
                        leftMargin: 72
                        rightMargin: 72
                        model: rowItem.modelData.items
                        currentIndex: root.colOf(rowItem.modelData.name)
                        highlightFollowsCurrentItem: true
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 72
                        preferredHighlightEnd: width - 72 - (rowItem.modelData.wide ? 320 : 150) * 1.1
                        highlightMoveDuration: 260
                        highlight: Item {}

                        delegate: Item {
                            id: slot

                            required property var modelData
                            required property int index
                            readonly property var item: modelData
                            readonly property var next: item.kind === "series" ? item.episodes[item.next] ?? null : null

                            width: card.width
                            height: cards.height

                            ReelCard {
                                id: card

                                anchors.verticalCenter: parent.verticalCenter
                                wide: rowItem.modelData.wide
                                image: wide ? (slot.next?.still || slot.item.backdrop || slot.item.poster || "") : (slot.item.poster || "")
                                caption: wide ? slot.item.title : ""
                                subcaption: wide ? (slot.next ? `${root.code(slot.next)}  ·  ${slot.next.title}` : root.left(slot.item)) : ""
                                progress: slot.item.progress
                                watched: slot.item.kind === "movie" && slot.item.watched
                                current: slot.index === cards.currentIndex
                                active: rowItem.active && root.page === "home"
                            }

                            MouseArea {
                                id: cardArea

                                anchors.fill: card
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => {
                                    if (!root.pointed(cardArea, mouse))
                                        return;
                                    root.row = rowItem.index;
                                    root.setCol(rowItem.modelData.name, slot.index);
                                }
                                onClicked: root.activate()
                            }
                        }
                    }
                }
            }

            // A series' page: the seasons, then its episodes
            Column {
                id: seriesPage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                spacing: 18
                visible: opacity > 0
                opacity: root.page === "series" ? 1 : 0
                transform: Translate {
                    y: root.page === "series" ? 0 : 60

                    Behavior on y {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.emphasizedDecel
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }
                }

                Row {
                    x: 72
                    spacing: 8

                    Repeater {
                        model: root.seasons

                        delegate: Rectangle {
                            id: chip

                            required property var modelData
                            readonly property bool on: root.currentEpisode?.season === modelData

                            width: seasonLabel.implicitWidth + 32
                            height: 36
                            radius: 18
                            color: on ? Theme.secondary_container : Theme.surface_container_high

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            Label {
                                id: seasonLabel

                                anchors.centerIn: parent
                                text: `Season ${chip.modelData}`
                                color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.episode = root.series.episodes.findIndex(e => e.season === chip.modelData)
                            }
                        }
                    }
                }

                ListView {
                    id: episodes

                    width: parent.width
                    height: 180 * 1.1 + 24
                    orientation: ListView.Horizontal
                    interactive: false
                    spacing: 22
                    leftMargin: 72
                    rightMargin: 72
                    model: root.series?.episodes ?? []
                    currentIndex: root.episode
                    highlightFollowsCurrentItem: true
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 72
                    preferredHighlightEnd: width - 72 - 320 * 1.1
                    highlightMoveDuration: 260
                    highlight: Item {}

                    delegate: Item {
                        id: epSlot

                        required property var modelData
                        required property int index

                        width: 320
                        height: episodes.height

                        ReelCard {
                            id: epCard

                            anchors.verticalCenter: parent.verticalCenter
                            wide: true
                            image: epSlot.modelData.still || root.series?.backdrop || ""
                            caption: epSlot.modelData.title || root.code(epSlot.modelData)
                            subcaption: root.code(epSlot.modelData)
                            progress: epSlot.modelData.progress
                            watched: epSlot.modelData.watched
                            current: epSlot.index === episodes.currentIndex
                            active: root.page === "series"
                        }

                        MouseArea {
                            id: epArea

                            anchors.fill: epCard
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => {
                                if (root.pointed(epArea, mouse))
                                    root.episode = epSlot.index;
                            }
                            onClicked: root.activate()
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.library !== null && root.rows.length === 0
                text: "Nothing in the library yet"
                color: Theme.on_surface_variant
                font.pixelSize: 20
            }
        }
    }

    // `qs -p <dir> ipc call reel toggle`, e.g. from the Entertainment menu
    IpcHandler {
        target: "reel"

        function toggle(): void {
            root.toggle();
        }
    }
}
