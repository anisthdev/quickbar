import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../.."
import "../../components"
import "Languages.js" as Languages

// A title's page in the video menu, over its tab: the backdrop behind the
// top (the poster, the title, "2009 · 1 h 35 min · 1080p", whether a show
// is still airing, its genres, its scores as badges), then the story, the
// buttons and the languages it plays in. A movie has its details along the
// bottom; a series its seasons and the season's episodes. The menu drives
// its keys through `list` and season().
Item {
    id: root

    // The title, from Reel's model (with progress, marks and languages)
    property var item: null
    property bool live: true
    readonly property bool series: item?.kind === "series"
    readonly property alias list: episodes
    // The season on show, and its episodes with their place in the series
    property int season: 0
    readonly property var seasons: series ? [...new Set(item.episodes.map(e => e.season))] : []
    // What has aired, season by season, from TMDB (null when reel doesn't
    // know): a season's announced episodes count once they're out
    readonly property var aired: {
        const t = item?.tmdb_seasons;
        if (!series || !t)
            return null;
        const last = item.last_air, today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return t.map(s => ({
                    season: s.season,
                    episodes: last ? (s.season < last.season ? s.episodes : s.season === last.season ? Math.min(s.episodes, last.episode ?? s.episodes) : 0) : (s.air_date && s.air_date <= today ? s.episodes : 0)
                })).filter(s => s.episodes > 0);
    }
    // The episodes on disk, by season
    readonly property var have: {
        const m = {};
        if (series)
            for (const e of item.episodes) {
                m[e.season] = m[e.season] ?? new Set();
                m[e.season].add(e.episode);
            }
        const counts = {};
        for (const k in m)
            counts[k] = m[k].size;
        return counts;
    }
    // Every season there is (aired, or on disk), for the chips
    readonly property var allSeasons: aired ? [...new Set(aired.map(s => s.season).concat(seasons))].sort((a, b) => a - b) : seasons
    readonly property var shown: series ? item.episodes.map((e, i) => ({
                episode: e,
                index: i
            })).filter(x => x.episode.season === season) : []
    // The episode picked, as an index into the series' episodes
    readonly property int pick: shown[episodes.currentIndex]?.index ?? -1
    readonly property var next: series ? item.episodes[item.next] ?? null : null

    // Enter on an episode or a button; index into the series' episodes, -1
    // for a movie
    signal play(int index, bool fromStart)
    signal action(string id)
    signal back

    function airedIn(n) {
        return aired?.find(s => s.season === n)?.episodes ?? 0;
    }

    function code(e) {
        return `S${String(e.season).padStart(2, "0")}E${String(e.episode).padStart(2, "0")}`;
    }

    function runtime(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function quality(x) {
        const w = x?.width ?? 0, h = x?.height ?? 0;
        return w >= 3200 || h >= 2000 ? "4K" : w >= 1800 || h >= 1000 ? "1080p" : w >= 1200 || h >= 700 ? "720p" : h > 0 ? "SD" : "";
    }

    // The languages it has: a series', every episode's
    function languages(kind) {
        const files = series ? item.episodes : item ? [item] : [];
        return [...new Set(files.reduce((all, f) => all.concat(f[kind] ?? []), []))].sort();
    }

    // Opened, or the series changed: at the episode it's up to (or the
    // one asked for)
    function showEpisode(index) {
        if (!series)
            return;
        const e = item.episodes[Math.max(0, index)];
        if (!e)
            return;
        season = e.season;
        Qt.callLater(() => {
            episodes.currentIndex = Math.max(0, shown.findIndex(x => x.index === index));
            episodes.positionViewAtIndex(episodes.currentIndex, ListView.Contain);
        });
    }

    // [ and ]: a season back or on
    function changeSeason(step) {
        const at = seasons.indexOf(season) + step;
        if (at < 0 || at >= seasons.length)
            return;
        season = seasons[at];
        Qt.callLater(() => {
            const n = item.next >= 0 && item.episodes[item.next].season === season ? shown.findIndex(x => x.index === item.next) : 0;
            episodes.currentIndex = Math.max(0, n);
            episodes.positionViewAtIndex(episodes.currentIndex, ListView.Contain);
        });
    }

    readonly property var actions: {
        if (!item)
            return [];
        const list = [];
        if (series) {
            const n = next;
            list.push({
                id: "play",
                label: n ? `${n.position > 0 ? "Carry on" : "Play"} ${code(n)}` : "Play from the start",
                icon: "media_play_arrow",
                primary: true
            });
            list.push({
                id: "upto",
                label: "Mark seen up to here  W",
                icon: "task_alt",
                primary: false
            });
        } else {
            list.push({
                id: "play",
                label: item.position > 0 ? "Resume  Enter" : "Play  Enter",
                icon: "media_play_arrow",
                primary: true
            });
            if (item.position > 0)
                list.push({
                    id: "start",
                    label: "Start over  P",
                    icon: "restart_alt",
                    primary: false
                });
            list.push({
                id: "watched",
                label: item.watched ? "Mark unseen  w" : "Mark seen  w",
                icon: "task_alt",
                primary: false
            });
        }
        list.push({
            id: "tracks",
            label: "Languages  t",
            icon: "translate",
            primary: false
        });
        return list;
    }

    // The scores Config.reelRatings asks for, in its order, where known; a
    // library from before reel kept more than TMDB's has that one as `rating`
    readonly property var ratings: {
        const r = item?.ratings ?? (item?.rating ? {
                tmdb: item.rating
            } : {});
        return (Config.reelRatings ?? []).filter(k => r[k]).map(k => ({
                    source: k,
                    score: r[k]
                }));
    }

    // Whether a show is on the air, and when it's next on: airing (an
    // episode out in the last fortnight or due in the next three weeks),
    // returning (between seasons), ended, canceled, upcoming
    readonly property var air: {
        const i = item;
        if (!series || !i?.status)
            return null;
        const now = new Date(), day = 24 * 3600 * 1000;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const at = d => d ? new Date(`${d.date}T00:00:00`).getTime() : NaN;
        const next = at(i.next_air), last = at(i.last_air);
        const when = t => {
            const days = Math.round((t - today) / day);
            return days === 0 ? "today" : days === 1 ? "tomorrow" : days > 1 && days < 7 ? Qt.formatDate(new Date(t), "dddd") : Qt.formatDate(new Date(t), new Date(t).getFullYear() === new Date(today).getFullYear() ? "d MMM" : "d MMM yyyy");
        };
        const nextCode = i.next_air?.episode ? `${code(i.next_air)}  ·  ` : "";
        if (i.status === "ended" || i.status === "canceled")
            return {
                state: i.status,
                label: i.status === "ended" ? "Ended" : "Canceled",
                detail: i.last_air ? i.last_air.date.slice(0, 4) : ""
            };
        if (next - today <= 21 * day || (i.status === "returning" && today - last <= 14 * day))
            return {
                state: "airing",
                label: "Airing",
                detail: next >= today ? `${nextCode}${when(next)}` : ""
            };
        if (i.status === "returning")
            return {
                state: "returning",
                label: "Returning",
                detail: next >= today ? `${i.next_air.season ? `Season ${i.next_air.season}  ·  ` : ""}${when(next)}` : ""
            };
        return {
            state: "upcoming",
            label: "Upcoming",
            detail: next >= today ? when(next) : ""
        };
    }

    // The backdrop behind the top of the page, darker where the text is,
    // and faded out by a mask (the panel's colours are translucent, so a
    // gradient to them would leave an edge)
    ClippingRectangle {
        id: backdropBox

        width: parent.width
        height: hero.height + 90
        topLeftRadius: Theme.cardRadius
        topRightRadius: Theme.cardRadius
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backdropMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Image {
            id: backdrop

            anchors.fill: parent
            source: root.live && root.item?.backdrop ? `file://${root.item.backdrop}` : ""
            sourceSize.width: 1000
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 0.45 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animNormal
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Theme.surface_container, 0.2)
                }
                GradientStop {
                    position: 0.75
                    color: Qt.alpha(Theme.surface_container, 0.65)
                }
            }
        }
    }

    Rectangle {
        id: backdropMask

        width: backdropBox.width
        height: backdropBox.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop {
                position: 0.45
                color: "white"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    // The poster, and beside it what this is: title, year and length, its
    // state and genres, its scores
    Item {
        id: hero

        x: 16
        y: 16
        width: parent.width - 32
        height: Math.max(poster.height, heroInfo.implicitHeight)

        ClippingRectangle {
            id: poster

            width: root.series ? 128 : 180
            height: width * 1.5
            radius: 12
            color: Theme.surface_container_highest

            Image {
                anchors.fill: parent
                source: root.live && root.item?.poster ? `file://${root.item.poster}` : ""
                sourceSize.width: 300
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
            }
        }

        Column {
            id: heroInfo

            anchors.left: poster.right
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 6

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
                    text: {
                        const i = root.item;
                        if (!i)
                            return "";
                        const kind = root.series ? (i.category === "Anime" ? "Anime" : "Series") : "Movie";
                        return root.series && i.network ? `${kind}  ·  ${i.network}` : kind;
                    }
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                }
            }

            // The title's logo where it has one (sized from logo_size before
            // it loads), else its name
            Item {
                id: titleBox

                readonly property real aspect: root.item?.logo_size?.[1] > 0 ? root.item.logo_size[0] / root.item.logo_size[1] : 0
                readonly property real logoHeight: aspect > 0 ? Math.min(root.series ? 60 : 76, Math.min(parent.width, 400) / aspect) : 0
                readonly property bool logo: !!root.item?.logo_image && aspect > 0 && logoImage.status !== Image.Error

                width: parent.width
                height: logo ? logoHeight + 4 : titleText.implicitHeight

                Image {
                    id: logoImage

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    visible: titleBox.logo
                    height: titleBox.logoHeight
                    width: height * titleBox.aspect
                    source: root.live && root.item?.logo_image ? `file://${root.item.logo_image}` : ""
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animNormal
                        }
                    }
                }

                Label {
                    id: titleText

                    anchors.verticalCenter: undefined
                    visible: !titleBox.logo
                    width: parent.width
                    text: root.item?.title ?? ""
                    color: Theme.on_surface
                    font.pixelSize: 28
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                    elide: Text.ElideRight
                }
            }

            // Year, length, quality, how far it's been watched; a series',
            // what's here of what has aired
            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: {
                    const i = root.item;
                    if (!i)
                        return "";
                    const parts = [i.year || ""];
                    if (root.series) {
                        const here = Object.values(root.have).reduce((a, b) => a + b, 0);
                        const out = root.aired ? root.aired.reduce((a, s) => a + s.episodes, 0) : 0;
                        const n = root.seasons.length, plural = x => x === 1 ? "season" : "seasons";
                        if (!root.aired || out === 0)
                            parts.push(`${n} ${plural(n)}`, `${here} episodes`);
                        else if (here >= out && n >= root.aired.length)
                            parts.push(n > 1 ? `${n} seasons` : "", `all ${out} episodes`);
                        else
                            parts.push(root.aired.length > 1 ? `${n} of ${root.aired.length} ${plural(root.aired.length)}` : "", `${here} of ${out} episodes`);
                        const seen = i.episodes.filter(e => e.watched).length;
                        if (seen > 0)
                            parts.push(`${seen} seen`);
                    } else {
                        parts.push(i.duration ? root.runtime(i.duration) : "", root.quality(i));
                        if (i.position > 0)
                            parts.push(`${root.runtime(i.duration - i.position)} left`);
                        else if (i.watched)
                            parts.push("Seen");
                    }
                    return parts.filter(x => x !== "").join("  ·  ");
                }
                color: Theme.on_surface_variant
                font.pixelSize: 13
                font.weight: Font.Normal
            }

            // On the air or not, then the genres
            Row {
                spacing: 6
                visible: root.air !== null || (root.item?.genres?.length ?? 0) > 0

                Rectangle {
                    id: airBadge

                    readonly property color ink: {
                        switch (root.air?.state) {
                        case "airing":
                            return Theme.on_primary;
                        case "canceled":
                            return Theme.on_error;
                        case "returning":
                        case "upcoming":
                            return Theme.on_tertiary_container;
                        default:
                            return Theme.on_surface;
                        }
                    }

                    visible: root.air !== null
                    width: airRow.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: {
                        switch (root.air?.state) {
                        case "airing":
                            return Theme.primary;
                        case "canceled":
                            return Theme.error;
                        case "returning":
                        case "upcoming":
                            return Theme.tertiary_container;
                        default:
                            return Theme.surface_container_highest;
                        }
                    }

                    Row {
                        id: airRow

                        anchors.centerIn: parent
                        spacing: 6

                        // A live dot while it's airing
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.air?.state === "airing"
                            width: 7
                            height: 7
                            radius: 3.5
                            color: airBadge.ink

                            SequentialAnimation on opacity {
                                running: root.live && root.air?.state === "airing"
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.35
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Label {
                            text: root.air?.label ?? ""
                            color: airBadge.ink
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Label {
                            visible: text !== ""
                            text: root.air?.detail ?? ""
                            color: airBadge.ink
                            opacity: 0.8
                            font.pixelSize: 12
                        }
                    }
                }

                Repeater {
                    model: root.item?.genres ?? []

                    Rectangle {
                        required property string modelData

                        width: genre.implicitWidth + 18
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Theme.outline, 0.5)

                        Label {
                            id: genre

                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Theme.on_surface_variant
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // The scores, inline
            Row {
                topPadding: 8
                spacing: 22
                visible: root.ratings.length > 0

                Repeater {
                    model: root.ratings

                    RatingBadge {
                        required property var modelData

                        source: modelData.source
                        score: modelData.score
                    }
                }
            }
        }
    }

    // The story, full width under the poster
    Column {
        id: about

        anchors.top: hero.bottom
        anchors.topMargin: 16
        x: 16
        width: parent.width - 32
        spacing: 4

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== ""
            text: root.item?.tagline ?? ""
            color: Theme.on_surface
            font.pixelSize: 14
            font.italic: true
            elide: Text.ElideRight
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: root.item?.overview ?? ""
            color: Theme.on_surface_variant
            font.pixelSize: 13
            font.weight: Font.Normal
            wrapMode: Text.WordWrap
            maximumLineCount: root.series ? 2 : 4
            elide: Text.ElideRight
            lineHeight: 1.2
        }
    }

    // The buttons, and the languages it'll play in
    Item {
        id: header

        anchors.top: about.bottom
        anchors.topMargin: 14
        x: 16
        width: parent.width - 32
        height: 34

        Row {
            id: buttons

            spacing: 8

            Repeater {
                model: root.actions

                Rectangle {
                    id: button

                    required property var modelData

                    width: buttonLabel.implicitWidth + 50
                    height: 34
                    radius: 17
                    color: modelData.primary ? (buttonMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary) : (buttonMouse.containsMouse ? Qt.alpha(Theme.secondary_container, 0.8) : Theme.secondary_container)

                    Icon {
                        x: 13
                        name: button.modelData.icon
                        size: 17
                        color: button.modelData.primary ? Theme.on_primary : Theme.on_secondary_container
                    }

                    Label {
                        id: buttonLabel

                        x: 36
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

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: buttons.width + width + 24 <= parent.width

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "translate"
                size: 14
                color: Theme.on_surface_variant
            }

            Label {
                text: {
                    const t = root.item?.tracks;
                    const audio = root.languages("audio"), subs = root.languages("subs");
                    const a = t?.audio ? Languages.name(t.audio) : audio.length === 1 ? Languages.name(audio[0]) : `Automatic (${audio.length})`;
                    const s = t?.subs ? Languages.name(t.subs) : subs.length === 0 ? "None" : `Automatic (${subs.length})`;
                    return `Audio: ${a}    Subtitles: ${s}`;
                }
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }
    }

    // A series' seasons, the one on show filled; [ and ] change it
    Row {
        id: seasonRow

        anchors.top: header.bottom
        anchors.topMargin: 14
        x: 16
        spacing: 4
        visible: root.series && root.allSeasons.length > 1

        // Every season: the ones on disk to pick (with how many of the
        // aired episodes are here, when not all), the rest faint
        Repeater {
            model: seasonRow.visible ? root.allSeasons : []

            Rectangle {
                id: chip

                required property int modelData
                readonly property bool on: modelData === root.season
                readonly property bool here: root.seasons.includes(modelData)
                readonly property int count: root.have[modelData] ?? 0
                readonly property int out: root.airedIn(modelData)

                width: chipLabel.implicitWidth + (root.allSeasons.length > 6 ? 18 : 24)
                height: 30
                radius: 15
                color: on ? Theme.secondary_container : chipMouse.containsMouse && here ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                border.width: here ? 0 : 1
                border.color: Qt.alpha(Theme.outline, 0.3)

                Label {
                    id: chipLabel

                    anchors.centerIn: parent
                    text: (root.allSeasons.length > 6 ? `S${chip.modelData}` : `Season ${chip.modelData}`) + (chip.here && chip.out > chip.count ? `  ${chip.count}/${chip.out}` : "")
                    color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                    opacity: chip.here ? 1 : 0.45
                    font.pixelSize: 12
                    font.weight: chip.on ? Font.DemiBold : Font.Medium
                }

                MouseArea {
                    id: chipMouse

                    anchors.fill: parent
                    enabled: chip.here
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.changeSeason(root.seasons.indexOf(chip.modelData) - root.seasons.indexOf(root.season))
                }
            }
        }

        Label {
            leftPadding: 10
            text: "[  ]"
            color: Theme.on_surface_variant
            font.family: Theme.monoFamily
            font.pixelSize: 12
        }
    }

    // The season's episodes, the pick kept on its episode as marks change
    ListView {
        id: episodes

        property string keptPath
        property var seen: null
        readonly property real rowHeight: 76

        anchors.top: seasonRow.visible ? seasonRow.bottom : header.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        visible: root.series
        model: root.shown
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightFollowsCurrentItem: false

        onCurrentIndexChanged: if (model === seen)
            keptPath = root.shown[currentIndex]?.episode.path ?? ""
        onModelChanged: {
            const was = keptPath;
            Qt.callLater(() => {
                seen = model;
                const i = root.shown.findIndex(x => x.episode.path === was);
                if (i >= 0)
                    currentIndex = i;
                keptPath = root.shown[currentIndex]?.episode.path ?? "";
            });
        }

        highlight: Rectangle {
            id: pickFill

            property bool settled: false

            Component.onCompleted: Qt.callLater(() => settled = true)

            y: episodes.currentItem?.y ?? 0
            width: episodes.width
            height: episodes.rowHeight
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

        delegate: EpisodeRow {
            id: row

            required property var modelData
            required property int index

            width: episodes.width
            height: episodes.rowHeight
            episode: modelData.episode
            live: root.live
            current: index === episodes.currentIndex
            next: modelData.index === root.item.next
            onClicked: episodes.currentIndex = index
            onActivated: {
                episodes.currentIndex = index;
                root.play(modelData.index, false);
            }

            Rectangle {
                parent: episodes.contentItem
                z: -1
                x: row.x
                y: row.y
                width: row.width
                height: row.height
                topLeftRadius: row.index === 0 ? Theme.radius : 3
                topRightRadius: row.index === 0 ? Theme.radius : 3
                bottomLeftRadius: row.index === episodes.count - 1 ? Theme.radius : 3
                bottomRightRadius: row.index === episodes.count - 1 ? Theme.radius : 3
                color: row.hovered && !row.current ? Theme.surface_container_highest : Theme.surface_container_high
            }
        }
    }

    // A movie's details, along the bottom of the page
    Grid {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: 16
        width: parent.width - 32
        visible: !root.series && root.item !== null
        columns: 4
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: {
                const i = root.item;
                if (!i || root.series)
                    return [];
                const audio = root.languages("audio"), subs = root.languages("subs");
                return [["Length", i.duration ? root.runtime(i.duration) : "—"], ["Picture", [root.quality(i), i.width && i.height ? `${i.width}×${i.height}` : ""].filter(x => x).join("  ·  ") || "—"], ["Audio", audio.map(Languages.name).join(", ") || "—"], ["Subtitles", subs.length > 4 ? `${subs.slice(0, 4).map(Languages.name).join(", ")} and ${subs.length - 4} more` : subs.map(Languages.name).join(", ") || "None"]];
            }

            Rectangle {
                required property var modelData

                width: (parent.width - 36) / 4
                height: 68
                radius: Theme.radius
                color: Theme.surface_container_high

                Column {
                    x: 14
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        anchors.verticalCenter: undefined
                        text: modelData[0]
                        color: Theme.on_surface_variant
                        font.pixelSize: 11
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        text: modelData[1]
                        color: Theme.on_surface
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
