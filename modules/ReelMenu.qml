import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"
import "music"
import "reel"

// The video library as one of the shell's menus: a panel at the bottom
// centre that springs open upwards, as the music menu does, with tabs for Continue (what's under way), Movies,
// Series and Anime, each a grid of posters with how far it's been watched.
// A title opens as a page over its tab (TitlePage): a movie's details, or a
// series' seasons and episodes. Playing goes through Reel, in mpv: a movie
// resumes where it stopped, a series plays from the episode on, the rest
// queued, in the languages picked for it (TrackPicker). Marks (seen, not
// seen) are kept by scripts/watch-progress, beside mpv's own progress.
//
// Keys, vim style: h/j/k/l move across the grid, gg/G go to the ends,
// Ctrl+d/u by two rows. Enter (or o) opens the title, p plays it (carries
// on), w marks it seen or not (a series: all of it), t picks its
// languages, s changes the order (recently played, recently added, title,
// rating, year). Tab/Shift+Tab or 1-4 switch tabs, / or i (or the search
// icon) filter by title, Esc clears the filter and then closes, as q and
// Ctrl+w do. On a page: j/k move through the season's episodes, [ and ]
// change season, Enter (or l) plays the episode (a movie: resumes), P plays
// it from its beginning, p carries on, w marks the episode seen or not, W
// marks every one up to it seen, t picks the languages, h, Esc or
// Backspace go back. ? lists the keys.
Scope {
    id: root

    // Reel: the library, its progress and mpv
    required property var reel

    readonly property var tabs: [
        {
            label: "Continue",
            category: ""
        },
        {
            label: "Movies",
            category: "Movies"
        },
        {
            label: "Series",
            category: "TV"
        },
        {
            label: "Anime",
            category: "Anime"
        }
    ]
    readonly property var sorts: ["Recently played", "Recently added", "Title", "Rating", "Year"]
    readonly property int columns: 6
    // [keys, what they do], for ? (KeyHelp)
    readonly property var gridBindings: [["h j k l", "Move"], ["gg G  Ctrl+d/u", "The ends, two rows"], ["Enter  o", "Open the title"], ["p", "Play: resume, or the next episode"], ["w", "Mark seen or not (a series: all of it)"], ["t", "Audio and subtitle languages"], ["s", "Change the order"], ["1-4  Tab", "Switch tabs"], ["/  i", "Filter by title (Esc back to the grid)"], ["Esc  q", "Clear the filter, then close"]]
    readonly property var pageBindings: [["j k  gg G", "Move through the episodes"], ["[  ]", "The season before, after"], ["Enter  l", "Play the episode, the rest after it (a movie: resume)"], ["P", "Play it from its beginning"], ["p", "Carry on: the next episode"], ["w", "Mark the episode (or movie) seen or not"], ["W", "Mark every episode up to it seen"], ["t", "Audio and subtitle languages"], ["Esc  h  Backspace", "Back"], ["q", "Close"]]

    property bool open: false
    property int tab: saved.tab
    property int sort: saved.sort
    // Filtering: the field shows, with the keys
    property bool filtering: false
    // The title whose page is open, by id, so it follows the model
    property string pageId: ""
    readonly property var page: pageId ? reel.model.items.find(i => i.id === pageId) ?? null : null
    // What the right of the header says for a moment, e.g. "Marked seen"
    property string flash

    readonly property string query: field.text.trim().toLowerCase()
    // The tab's titles, in the order picked (Continue: most recent first),
    // matching the filter ranked as the launcher menus do
    readonly property var items: {
        const category = tabs[tab].category;
        let all;
        if (!category) {
            all = reel.rows.find(r => r.name === "Continue watching")?.items ?? [];
        } else {
            all = reel.model.items.filter(i => i.category === category);
            const title = (a, b) => a.title.localeCompare(b.title);
            const by = [(a, b) => b.lastPlayed - a.lastPlayed || (b.added ?? 0) - (a.added ?? 0) || title(a, b), (a, b) => (b.added ?? 0) - (a.added ?? 0) || title(a, b), title, (a, b) => (b.rating ?? 0) - (a.rating ?? 0) || title(a, b), (a, b) => (b.year ?? 0) - (a.year ?? 0) || title(a, b)][sort];
            all = all.slice().sort(by);
        }
        if (query === "")
            return all;
        const rank = item => {
            const t = item.title.toLowerCase();
            if (t.startsWith(query))
                return 0;
            if (t.split(/[\s\-_.:,()]+/).some(w => w.startsWith(query)))
                return 1;
            if (t.includes(query))
                return 2;
            return (item.genres ?? []).some(g => g.toLowerCase().startsWith(query)) ? 3 : -1;
        };
        return all.map((item, i) => ({
                    item,
                    i,
                    r: rank(item)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.item);
    }
    readonly property var current: items[grid.currentIndex] ?? null

    // The pick to the first title, with nothing to keep it on
    function toFirst() {
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
        grid.keptId = "";
    }

    function show() {
        reel.load();
        field.text = "";
        flash = "";
        pageId = "";
        filtering = false;
        open = true;
        toFirst();
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    function startFilter() {
        pageId = "";
        filtering = true;
        field.forceActiveFocus();
    }

    function stopFilter() {
        filtering = false;
        keys.forceActiveFocus();
    }

    function switchTo(index) {
        pageId = "";
        tab = (index + tabs.length) % tabs.length;
        saved.tab = tab;
        toFirst();
    }

    function changeSort() {
        if (tab === 0)
            return say("Continue keeps the latest first");
        sort = (sort + 1) % sorts.length;
        saved.sort = sort;
        toFirst();
        say(`By ${sorts[sort].toLowerCase()}`);
    }

    function say(text) {
        flash = text;
        flashTimer.restart();
    }

    function count(n, one, many) {
        return `${n} ${n === 1 ? one : many}`;
    }

    function nextOf(item) {
        return item?.kind === "series" ? item.episodes[item.next] ?? null : null;
    }

    // The poster's bar: a movie's position; a series' episodes seen, the
    // one going counting for its part
    function progressOf(item) {
        if (item.kind === "movie")
            return item.watched ? 0 : item.progress;
        const done = item.episodes.filter(e => e.watched).length;
        if (done === item.episodes.length)
            return 0;
        return (done + (nextOf(item)?.progress ?? 0)) / Math.max(1, item.episodes.length);
    }

    function seenAll(item) {
        return item.kind === "movie" ? item.watched : item.episodes.length > 0 && item.episodes.every(e => e.watched);
    }

    // Under the title: where it's at
    function statusOf(item) {
        if (item.kind === "movie") {
            if (item.position > 0)
                return reel.left(item);
            return [item.year || "", item.duration ? reel.runtime(item.duration) : ""].filter(b => b !== "").join("  ·  ");
        }
        const next = nextOf(item);
        if (next && item.started)
            return next.position > 0 ? `${reel.code(next)}  ·  ${reel.left(next)}` : `${reel.code(next)}  ·  ${item.next + 1} of ${item.episodes.length}`;
        return [item.year || "", count(item.episodes.length, "episode", "episodes")].filter(b => b !== "").join("  ·  ");
    }

    function openPage(item) {
        if (!item)
            return;
        pageId = item.id;
        if (item.kind === "series")
            Qt.callLater(() => pageView.showEpisode(Math.max(0, item.next)));
    }

    function back() {
        pageId = "";
    }

    // A movie resumes (or starts over); a series plays from the episode,
    // the rest queued after it
    function play(item, index, fromStart) {
        if (!item)
            return;
        reel.play(item, item.kind === "movie" ? 0 : Math.max(0, index), fromStart);
        hide();
    }

    // p: carry on, from the grid or a page
    function carryOn(item) {
        if (item)
            play(item, item.kind === "series" ? item.next : 0, false);
    }

    // w on the grid: a movie, or all of a series, seen or not
    function toggleSeen(item) {
        if (!item)
            return;
        const seen = seenAll(item);
        grid.keptId = item.id;
        reel.mark(item.kind === "movie" ? [item] : item.episodes, !seen);
        say(seen ? `${item.title}: not seen` : `${item.title}: seen`);
    }

    // w on a page: the movie, or the episode picked
    function toggleSeenOnPage() {
        if (!page)
            return;
        if (page.kind === "movie")
            return toggleSeen(page);
        const e = page.episodes[pageView.pick];
        if (!e)
            return;
        reel.mark([e], !e.watched);
        say(`${reel.code(e)}: ${e.watched ? "not seen" : "seen"}`);
    }

    // W: every episode up to the one picked
    function seenUpTo() {
        if (page?.kind !== "series" || pageView.pick < 0)
            return;
        const upTo = page.episodes.slice(0, pageView.pick + 1);
        reel.mark(upTo.filter(e => !e.watched), true);
        say(`Seen up to ${reel.code(page.episodes[pageView.pick])}`);
    }

    // t: the title's languages, through the picker
    function pickTracks(item) {
        if (!item)
            return;
        const files = item.kind === "series" ? item.episodes : [item];
        const langs = kind => [...new Set(files.reduce((all, f) => all.concat(f[kind] ?? []), []))].sort();
        picker.ask(item.title, langs("audio"), langs("subs"), item.tracks, (audio, subs) => {
            reel.setTracks(item, audio, subs);
            say(audio || subs ? "Languages kept" : "Languages: mpv's choice");
        });
    }

    function pageAction(id) {
        if (!page)
            return;
        if (id === "play")
            carryOn(page);
        else if (id === "start")
            play(page, 0, true);
        else if (id === "watched")
            toggleSeen(page);
        else if (id === "upto")
            seenUpTo();
        else if (id === "tracks")
            pickTracks(page);
    }

    // Enter: opens the title; on a page, plays the episode (a movie resumes)
    function activate() {
        if (!page)
            openPage(current);
        else if (page.kind === "movie")
            play(page, 0, false);
        else if (pageView.pick >= 0)
            play(page, pageView.pick, false);
    }

    // The grid's moves: h/l along, j/k a row
    function gridKey(event) {
        if (page || event.modifiers & Qt.ControlModifier)
            return false;
        const t = event.text;
        if (t === "h" || event.key === Qt.Key_Left)
            grid.moveCurrentIndexLeft();
        else if (t === "l" || event.key === Qt.Key_Right)
            grid.moveCurrentIndexRight();
        else if (t === "j" || event.key === Qt.Key_Down)
            grid.moveCurrentIndexDown();
        else if (t === "k" || event.key === Qt.Key_Up)
            grid.moveCurrentIndexUp();
        else
            return false;
        return true;
    }

    function listKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const t = event.text;
        if (t === "?" || event.key === Qt.Key_F1) {
            help.show(page ? pageBindings : gridBindings);
            return true;
        }
        if (ctrl && event.key === Qt.Key_W) {
            hide();
            return true;
        }
        if (gridKey(event))
            return true;
        // On a page, the keys move the episodes; a movie's has none
        if (page?.kind === "series" && listKeys.handle(event))
            return true;
        if (!page && listKeys.handle(event))
            return true;
        if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            switchTo(tab - 1);
            return true;
        }
        if (event.key === Qt.Key_Tab) {
            switchTo(tab + 1);
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activate();
            return true;
        }
        if (page && (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || t === "h")) {
            back();
            return true;
        }
        if (event.key === Qt.Key_Escape) {
            if (field.text !== "")
                field.text = "";
            else
                hide();
            return true;
        }
        if (ctrl)
            return false;
        switch (t) {
        case "q":
            hide();
            return true;
        case "o":
            if (!page)
                openPage(current);
            return true;
        case "l":
            // On the grid, l moves (gridKey); on a page it plays
            activate();
            return true;
        case "p":
            carryOn(page ?? current);
            return true;
        case "P":
            if (page?.kind === "movie")
                play(page, 0, true);
            else if (page && pageView.pick >= 0)
                play(page, pageView.pick, true);
            return true;
        case "w":
            page ? toggleSeenOnPage() : toggleSeen(current);
            return true;
        case "W":
            seenUpTo();
            return true;
        case "t":
            pickTracks(page ?? current);
            return true;
        case "[":
        case "]":
            if (page)
                pageView.changeSeason(t === "]" ? 1 : -1);
            return true;
        case "s":
            if (!page)
                changeSort();
            return true;
        case "/":
        case "i":
            startFilter();
            return true;
        case "1":
        case "2":
        case "3":
        case "4":
            switchTo(parseInt(t) - 1);
            return true;
        }
        return false;
    }

    function fieldKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Down || ctrl && event.key === Qt.Key_J)
            grid.moveCurrentIndexRight();
        else if (event.key === Qt.Key_Up || ctrl && event.key === Qt.Key_K)
            grid.moveCurrentIndexLeft();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            stopFilter();
            openPage(current);
        } else if (event.key === Qt.Key_Escape)
            stopFilter();
        else if (ctrl && event.key === Qt.Key_W)
            hide();
        else
            return false;
        return true;
    }

    // The tab and order it was left on, kept through reloads too
    PersistentProperties {
        id: saved

        reloadableId: "reelMenu"

        property int tab: 1
        property int sort: 0
    }

    Timer {
        id: flashTimer

        interval: 2500
        onTriggered: root.flash = ""
    }

    PanelWindow {
        id: window

        property real reveal: 0

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
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
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

        // A click anywhere else closes it
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            // Two rows of posters; a page gets the same room
            readonly property real cellWidth: (width - 40) / root.columns
            readonly property real cellHeight: (cellWidth - 16) * 1.5 + 16 + 44
            readonly property real contentHeight: 2 * cellHeight
            readonly property real fullHeight: Math.min(window.height - 32 - 60, 26 + header.height + fieldBox.height + 12 + contentHeight + 20)

            // Bottom centre, where the shell's menus open, growing upwards
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: Math.min(1000, window.width - 32)
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            // Swallow clicks on the panel itself
            MouseArea {
                anchors.fill: parent
            }

            // Laid out at full height, so folding only uncovers it
            Item {
                x: 20
                y: 26
                width: parent.width - 40
                height: panel.fullHeight - 26 - 20

                Item {
                    id: keys

                    Keys.onPressed: event => event.accepted = root.listKey(event)
                }

                ListKeys {
                    id: listKeys

                    list: root.page ? pageView.list : grid
                    halfPage: root.page ? 3 : 2 * root.columns
                }

                // The title, the tabs, and the tab's size and order (or a
                // word on what just happened), and the filter's button
                Item {
                    id: header

                    width: parent.width
                    height: 34

                    Label {
                        id: title

                        x: 2
                        text: "Videos"
                        color: Theme.primary
                        font.pixelSize: 26
                        font.weight: Theme.titleWeight
                        roundness: Theme.titleRoundness
                    }

                    Row {
                        anchors.left: title.right
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: root.tabs

                            Rectangle {
                                id: chip

                                required property var modelData
                                required property int index
                                readonly property bool on: index === root.tab

                                width: chipLabel.implicitWidth + 28
                                height: 32
                                radius: height / 2
                                color: on ? Theme.secondary_container : chipMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                    }
                                }

                                Label {
                                    id: chipLabel

                                    anchors.centerIn: parent
                                    text: chip.modelData.label
                                    color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                                    font.pixelSize: 13
                                    font.weight: chip.on ? Font.DemiBold : Font.Medium
                                }

                                MouseArea {
                                    id: chipMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.switchTo(chip.index)
                                }
                            }
                        }
                    }

                    Label {
                        anchors.right: searchButton.left
                        anchors.rightMargin: 12
                        text: {
                            if (root.flash)
                                return root.flash;
                            const n = root.count(root.items.length, "title", "titles");
                            return root.tab === 0 || root.page ? n : `${n}  ·  ${root.sorts[root.sort].toLowerCase()}  s`;
                        }
                        color: root.flash ? Theme.primary : Theme.on_surface_variant
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            enabled: !root.flash && !root.page
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeSort()
                        }
                    }

                    // The filter, hidden until / or this
                    Rectangle {
                        id: searchButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: root.filtering ? Theme.secondary_container : searchMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            name: "search"
                            size: 18
                            color: root.filtering ? Theme.on_secondary_container : Theme.on_surface_variant
                        }

                        MouseArea {
                            id: searchMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filtering ? root.stopFilter() : root.startFilter()
                        }
                    }
                }

                // The filter: shown while filtering, or while it has text
                Item {
                    id: fieldBox

                    readonly property bool shown: root.filtering || field.text !== ""

                    anchors.top: header.bottom
                    width: parent.width
                    height: shown ? 58 : 0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        y: 14
                        width: parent.width
                        height: 44
                        radius: Theme.radius
                        color: Theme.surface_container_high
                        border.width: root.filtering ? 2 : 0
                        border.color: Theme.primary

                        Icon {
                            x: 16
                            name: "search"
                            size: 18
                            color: Theme.on_surface_variant
                        }

                        TextInput {
                            id: field

                            anchors.left: parent.left
                            anchors.leftMargin: 46
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.on_surface
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.on_primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            clip: true
                            onTextChanged: root.toFirst()
                            Keys.onPressed: event => event.accepted = root.fieldKey(event)
                            onActiveFocusChanged: if (activeFocus) {
                                root.filtering = true;
                                root.pageId = "";
                            }

                            Label {
                                anchors.verticalCenter: undefined
                                visible: field.text === ""
                                text: `Filter ${root.tabs[root.tab].label.toLowerCase()} by title or genre`
                                color: Theme.on_surface_variant
                                font: field.font
                            }
                        }
                    }
                }

                // The tab's grid, and a page sliding in over it
                Item {
                    id: content

                    anchors.top: fieldBox.bottom
                    anchors.topMargin: 12
                    width: parent.width
                    height: panel.contentHeight
                    clip: true

                    Item {
                        id: tabView

                        width: parent.width
                        height: parent.height
                        x: root.page ? -32 : 0
                        opacity: root.page ? 0 : 1
                        visible: opacity > 0

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }

                        // Posters, six across, the pick's fill sliding
                        // between them. Once moved to (or marked), the pick
                        // stays on its title as the list changes under it
                        GridView {
                            id: grid

                            property string keptId
                            property var seen: null

                            anchors.fill: parent
                            model: root.items
                            cellWidth: panel.cellWidth
                            cellHeight: panel.cellHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightRangeMode: GridView.ApplyRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: height
                            highlightFollowsCurrentItem: false

                            onCurrentIndexChanged: if (model === seen)
                                keptId = root.items[currentIndex]?.id ?? ""
                            onModelChanged: {
                                const was = keptId;
                                Qt.callLater(() => {
                                    seen = model;
                                    const i = was ? root.items.findIndex(x => x.id === was) : -1;
                                    if (i >= 0)
                                        currentIndex = i;
                                });
                            }

                            highlight: Rectangle {
                                id: cellFill

                                property bool settled: false

                                Component.onCompleted: Qt.callLater(() => settled = true)

                                x: grid.currentItem?.x ?? 0
                                y: grid.currentItem?.y ?? 0
                                width: grid.cellWidth
                                height: grid.cellHeight
                                radius: Theme.cardRadius
                                color: Theme.secondary_container

                                Behavior on x {
                                    enabled: cellFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on y {
                                    enabled: cellFill.settled
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            delegate: PosterCell {
                                required property var modelData
                                required property int index

                                width: grid.cellWidth
                                height: grid.cellHeight
                                item: modelData
                                live: window.visible
                                current: index === grid.currentIndex
                                status: root.statusOf(modelData)
                                progress: root.progressOf(modelData)
                                watched: root.seenAll(modelData)
                                next: modelData.kind === "series" && modelData.started && root.nextOf(modelData) ? root.reel.code(root.nextOf(modelData)) : ""
                                onClicked: grid.currentIndex = index
                                onActivated: root.openPage(modelData)
                            }
                        }

                        // Nothing to show, or not yet
                        Label {
                            anchors.centerIn: parent
                            visible: grid.count === 0
                            text: !root.reel.library ? "Reading the library…" : root.query ? "Nothing matches" : root.tab === 0 ? "Nothing under way: p on a title plays it" : `No ${root.tabs[root.tab].label.toLowerCase()} yet: Movies/TV search downloads them`
                            color: Theme.on_surface_variant
                            font.weight: Font.Normal
                        }
                    }

                    TitlePage {
                        id: pageView

                        width: parent.width
                        height: parent.height
                        x: root.page ? 0 : 48
                        opacity: root.page ? 1 : 0
                        visible: opacity > 0
                        item: root.page
                        live: window.visible
                        onPlay: (index, fromStart) => root.play(root.page, index, fromStart)
                        onAction: id => root.pageAction(id)
                        onBack: root.back()

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.emphasizedDecel
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                // t's language picker, over it all
                TrackPicker {
                    id: picker

                    anchors.margins: -12
                    onFinished: keys.forceActiveFocus()
                }

                KeyHelp {
                    id: help

                    anchors.margins: -12
                    onFinished: keys.forceActiveFocus()
                }
            }
        }
    }

    // `qs -c quickbar ipc call reelmenu toggle`, e.g. from Super+M
    IpcHandler {
        target: "reelmenu"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            if (!root.open)
                root.show();
        }
    }
}
