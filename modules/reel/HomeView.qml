import QtQuick
import "../.."
import "../../components"
import "Plan.js" as Plan

// The video window's Home, as a streaming app's: a few titles as big cards
// across the top (what's under way, what came in lately, the best scored
// not seen), then shelves: Continue watching, New episodes, Recently added,
// each of reel's rows, Top rated and the biggest genres. A shelf that has
// more than it shows has all of it a key (a) or a click (›) away.
//
// Keys come from the menu: j/k (list, through ListKeys) move between
// shelves, along(±1) moves along one; each shelf keeps its place. The pick
// is `current`.
Item {
    id: root

    // Reel: the library and its progress
    required property var reel
    property bool live: true
    // On show and not paused: the hero pages by itself
    property bool active: false
    // The rows' labels, by reel's names ("TV": "Series")
    property var rowLabels: ({})

    readonly property alias list: shelfList
    readonly property var shelves: build(reel.model.items, reel.rows, reel.library?.rows ?? [])
    readonly property var shelf: shelves[shelfList.currentIndex] ?? null
    // Where each shelf is at, by its key
    property var places: ({})
    readonly property var current: shelf ? shelf.items[placeIn(shelf)] ?? null : null

    signal open(var item)
    signal play(var item)
    signal all(var shelf)

    readonly property int shelfSize: 20
    readonly property real heroHeight: Math.round(Math.max(300, Math.min(500, height * 0.64)))

    function placeIn(s) {
        return Math.max(0, Math.min(s.items.length - 1, places[s.key] ?? 0));
    }

    function place(key, index) {
        if (places[key] === index)
            return;
        const p = Object.assign({}, places);
        p[key] = index;
        places = p;
    }

    // h/l: along the shelf (the hero pages round)
    function along(step) {
        const s = shelf;
        if (!s || s.items.length === 0)
            return;
        const at = placeIn(s) + step;
        if (s.kind === "hero")
            place(s.key, (at + s.items.length) % s.items.length);
        else
            place(s.key, Math.max(0, Math.min(s.items.length - 1, at)));
    }

    function toTop() {
        shelfList.currentIndex = 0;
        shelfList.positionViewAtBeginning();
    }

    // Seen to the end (or marked so)
    function seenAll(i) {
        return Plan.seenAll(i);
    }

    function byScore(a, b) {
        return (seenAll(a) - seenAll(b)) || ((Plan.score(b, Config.reelRatings)?.value ?? 0) - (Plan.score(a, Config.reelRatings)?.value ?? 0));
    }

    function build(items, rows, names) {
        const out = [];
        if (!items || items.length === 0)
            return out;
        const now = Date.now() / 1000;
        const going = rows.find(r => r.name === "Continue watching")?.items ?? [];
        const goingIds = new Set(going.map(i => i.id));
        const recent = (a, b) => (b.added ?? 0) - (a.added ?? 0) || a.title.localeCompare(b.title);
        const count = n => `${n} title${n === 1 ? "" : "s"}`;

        // The big cards: under way first, then new and not seen, then the
        // best scored not seen; those with a backdrop before those without
        const pictured = items.filter(i => i.backdrop);
        const pool = pictured.length > 0 ? pictured : items;
        const fresh = pool.filter(i => !seenAll(i)).sort(recent).slice(0, 2);
        const best = pool.filter(i => !seenAll(i) && Plan.score(i, Config.reelRatings)).sort(byScore).slice(0, 6);
        const featured = [];
        for (const i of going.filter(i => i.backdrop || pictured.length === 0).slice(0, 2).concat(fresh, best))
            if (!featured.some(f => f.id === i.id) && featured.length < 6)
                featured.push(i);
        if (featured.length > 0)
            out.push({
                key: "hero",
                kind: "hero",
                items: featured
            });

        if (going.length > 0)
            out.push({
                key: "continue",
                kind: "wide",
                label: "Continue watching",
                subtitle: "Pick up where you left off",
                items: going.slice(0, shelfSize),
                all: going.length > shelfSize ? going : null
            });

        // Shows begun, with an episode in lately not seen, not carried on
        // with above
        const newest = items.filter(i => i.kind === "series" && !goingIds.has(i.id) && i.started).map(i => {
            const eps = i.episodes.filter(e => now - (e.added ?? 0) < 14 * 24 * 3600 && !e.watched);
            const latest = eps.reduce((a, e) => !a || (e.added ?? 0) > (a.added ?? 0) ? e : a, null);
            return latest ? {
                item: i,
                episode: latest
            } : null;
        }).filter(x => x).sort((a, b) => (b.episode.added ?? 0) - (a.episode.added ?? 0));
        if (newest.length > 0) {
            const badges = {};
            for (const n of newest)
                badges[n.item.id] = Plan.code(n.episode);
            out.push({
                key: "new",
                kind: "backdrop",
                label: "New episodes",
                subtitle: "Come in since you last watched",
                items: newest.map(n => n.item),
                badges
            });
        }

        const added = items.slice().sort(recent);
        out.push({
            key: "added",
            kind: "backdrop",
            label: "Recently added",
            subtitle: "New in your library",
            items: added.slice(0, shelfSize),
            all: added
        });

        for (const name of names) {
            const inRow = items.filter(i => i.category === name).sort((a, b) => b.lastPlayed - a.lastPlayed || recent(a, b));
            if (inRow.length > 0)
                out.push({
                    key: `row:${name}`,
                    kind: "poster",
                    label: rowLabels[name] ?? name,
                    subtitle: `${count(inRow.length)}  ·  recently played or added`,
                    row: name,
                    items: inRow.slice(0, shelfSize),
                    all: inRow
                });
        }

        const top = items.filter(i => Plan.score(i, Config.reelRatings)).sort(byScore);
        if (top.length > 0) {
            const badges = {};
            for (const i of top) {
                const s = Plan.score(i, Config.reelRatings);
                badges[i.id] = s.source === "rt" ? `${Math.round(s.value)}%` : s.source === "metacritic" ? `${Math.round(s.value)}` : s.value.toFixed(1);
            }
            const order = Config.reelRatings ?? [];
            out.push({
                key: "top",
                kind: "poster",
                label: "Top rated",
                subtitle: order.length > 0 ? `By ${order.map(k => ({
                                imdb: "IMDb",
                                mal: "MyAnimeList",
                                rt: "Rotten Tomatoes",
                                metacritic: "Metacritic",
                                tmdb: "TMDB"
                            })[k] ?? k).join(", else ")}` : "By TMDB",
                items: top.slice(0, shelfSize),
                all: top,
                badges
            });
        }

        // The three biggest genres, with enough in them to be a shelf
        const genres = {};
        for (const i of items)
            for (const g of i.genres ?? [])
                genres[g] = (genres[g] ?? 0) + 1;
        Object.entries(genres).filter(([, n]) => n >= 4).sort((a, b) => b[1] - a[1]).slice(0, 3).forEach(([genre, n]) => {
            const inGenre = items.filter(i => (i.genres ?? []).includes(genre)).sort(byScore);
            out.push({
                key: `genre:${genre}`,
                kind: "poster",
                label: genre,
                subtitle: count(n),
                items: inGenre.slice(0, shelfSize),
                all: inGenre
            });
        });
        return out;
    }

    // The hero pages by itself while it isn't the pick
    Timer {
        interval: 9000
        repeat: true
        running: root.active && root.shelves[0]?.kind === "hero" && shelfList.currentIndex !== 0
        onTriggered: {
            const s = root.shelves[0];
            root.place(s.key, (root.placeIn(s) + 1) % s.items.length);
        }
    }

    ListView {
        id: shelfList

        // The shelf picked, kept by its key as the shelves change
        property string keptKey
        property var seen: null

        anchors.fill: parent
        model: root.shelves
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 6
        topMargin: 6
        bottomMargin: 16
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightMoveDuration: 320
        highlightResizeDuration: 0
        highlight: Item {}

        onCurrentIndexChanged: if (model === seen)
            keptKey = root.shelves[currentIndex]?.key ?? ""
        onModelChanged: {
            const was = keptKey;
            Qt.callLater(() => {
                seen = model;
                const i = was ? root.shelves.findIndex(s => s.key === was) : -1;
                if (i >= 0)
                    positionViewAtIndex(currentIndex = i, ListView.Contain);
            });
        }

        delegate: Loader {
            id: shelfItem

            required property var modelData
            required property int index
            readonly property bool picked: index === shelfList.currentIndex

            width: shelfList.width
            sourceComponent: modelData.kind === "hero" ? heroShelf : cardShelf
        }
    }

    Component {
        id: heroShelf

        // The big cards, the next peeking in at the side
        Item {
            id: heroBox

            readonly property var shelf: parent.modelData
            readonly property bool picked: parent.picked

            height: root.heroHeight + 26

            ListView {
                id: heroList

                x: 4
                y: 4
                width: parent.width - 8
                height: root.heroHeight
                orientation: ListView.Horizontal
                model: heroBox.shelf.items
                spacing: 16
                clip: false
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width - 72
                highlightMoveDuration: 450
                highlight: Item {}
                Component.onCompleted: currentIndex = root.placeIn(heroBox.shelf)
                // A flick pages it too
                onCurrentIndexChanged: root.place(heroBox.shelf.key, currentIndex)

                Connections {
                    target: root

                    function onPlacesChanged() {
                        const want = root.placeIn(heroBox.shelf);
                        if (heroList.currentIndex !== want)
                            heroList.currentIndex = want;
                    }
                }

                delegate: HeroCard {
                    required property var modelData
                    required property int index

                    width: heroList.width - 72
                    height: heroList.height
                    item: modelData
                    live: root.live
                    focused: heroBox.picked && index === heroList.currentIndex
                    opacity: index === heroList.currentIndex ? 1 : 0.55
                    onClicked: {
                        shelfList.currentIndex = heroBox.parent.index;
                        heroList.currentIndex = index;
                    }
                    onActivated: root.open(modelData)
                    onPlay: root.play(modelData)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animNormal
                        }
                    }
                }
            }

            // Which card, of how many
            Row {
                anchors.horizontalCenter: heroList.horizontalCenter
                anchors.top: heroList.bottom
                anchors.topMargin: 10
                spacing: 6
                visible: heroBox.shelf.items.length > 1

                Repeater {
                    model: heroBox.shelf.items.length

                    Rectangle {
                        required property int index
                        readonly property bool on: index === heroList.currentIndex

                        width: on ? 22 : 7
                        height: 7
                        radius: 3.5
                        color: on ? Theme.primary : Qt.alpha(Theme.on_surface, 0.25)

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cardShelf

        // A heading (and a line under it), a › when there's more, the cards
        Item {
            id: shelfBox

            readonly property var shelf: parent.modelData
            readonly property bool picked: parent.picked
            readonly property real cardWidth: shelf.kind === "poster" ? Math.max(130, Math.min(170, (root.width - 40) / 7)) : Math.max(240, Math.min(320, (root.width - 40) / 3.6))
            readonly property real cardHeight: shelf.kind === "poster" ? cardWidth * 1.5 + 50 : shelf.kind === "wide" ? cardWidth * 9 / 16 + 50 : cardWidth * 9 / 16

            height: heading.height + cards.height + 4

            Item {
                id: heading

                x: 6
                width: parent.width - 12
                height: 58

                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: parent.width - 60
                    spacing: 1

                    Label {
                        anchors.verticalCenter: undefined
                        text: shelfBox.shelf.label
                        color: shelfBox.picked ? Theme.on_surface : Qt.alpha(Theme.on_surface, 0.85)
                        font.pixelSize: 19
                        font.weight: Theme.titleWeight
                        roundness: Theme.titleRoundness
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        text: shelfBox.shelf.subtitle ?? ""
                        color: Theme.on_surface_variant
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }

                // All of it: a, or this
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    visible: !!shelfBox.shelf.all
                    width: allRow.implicitWidth + 22
                    height: 32
                    radius: 16
                    color: allMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                    Row {
                        id: allRow

                        anchors.centerIn: parent
                        spacing: 6

                        Label {
                            visible: shelfBox.picked
                            text: "a"
                            color: Theme.on_surface_variant
                            font.family: Theme.monoFamily
                            font.pixelSize: 11
                        }

                        Label {
                            text: "All"
                            color: Theme.on_surface
                            font.pixelSize: 12
                        }

                        Icon {
                            name: "keyboard_arrow_right"
                            size: 16
                            color: Theme.on_surface
                        }
                    }

                    MouseArea {
                        id: allMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.all(shelfBox.shelf)
                    }
                }
            }

            ListView {
                id: cards

                anchors.top: heading.bottom
                width: parent.width
                // Room for the pick to grow, and its ring
                height: shelfBox.cardHeight + 24
                orientation: ListView.Horizontal
                model: shelfBox.shelf.items
                spacing: shelfBox.shelf.kind === "poster" ? 18 : 20
                leftMargin: 12
                rightMargin: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 12
                preferredHighlightEnd: width - 12
                highlightMoveDuration: 260
                highlightResizeDuration: 0
                highlight: Item {}
                currentIndex: root.placeIn(shelfBox.shelf)

                // The card a little way down, with room above it for the
                // pick to grow into (a horizontal list's topMargin doesn't)
                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    width: shelfBox.cardWidth
                    height: cards.height

                    ShelfCard {
                        y: 12
                        width: parent.width
                        height: shelfBox.cardHeight
                        item: cell.modelData
                        kind: shelfBox.shelf.kind
                        live: root.live
                        focused: shelfBox.picked && cell.index === cards.currentIndex
                        badge: shelfBox.shelf.badges?.[cell.modelData.id] ?? ""
                        onClicked: {
                            shelfList.currentIndex = shelfBox.parent.index;
                            root.place(shelfBox.shelf.key, cell.index);
                        }
                        onActivated: root.open(cell.modelData)
                    }
                }
            }
        }
    }
}
