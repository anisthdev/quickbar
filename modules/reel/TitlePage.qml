import QtQuick
import Quickshell.Widgets
import "../.."
import "../../components"
import "Languages.js" as Languages

// A title's page in the video menu, over its tab: the backdrop faint
// behind a header (the poster, the title, "2009 · 1 h 35 min · 1080p",
// its genres, the story, the languages it plays in, its buttons). A movie
// has its details under that; a series its seasons and the season's
// episodes. The menu drives its keys through `list` and season().
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

    // The backdrop, faint, fading into the panel
    ClippingRectangle {
        width: parent.width
        height: 250
        radius: Theme.cardRadius
        color: "transparent"

        Image {
            id: backdrop

            anchors.fill: parent
            source: root.live && root.item?.backdrop ? `file://${root.item.backdrop}` : ""
            sourceSize.width: 780
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 0.3 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animNormal
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.3
                    color: Qt.alpha(Theme.surface_container, 0)
                }
                GradientStop {
                    position: 1
                    color: Theme.surface_container
                }
            }
        }
    }

    Item {
        id: header

        x: 16
        y: 16
        width: parent.width - 32
        height: Math.max(poster.height, details.implicitHeight)

        ClippingRectangle {
            id: poster

            width: root.series ? 120 : 150
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
            id: details

            anchors.left: poster.right
            anchors.leftMargin: 20
            anchors.right: parent.right
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
                    text: !root.item ? "" : root.series ? (root.item.category === "Anime" ? "Anime" : "Series") : "Movie"
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                }
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.item?.title ?? ""
                color: Theme.on_surface
                font.pixelSize: 24
                font.weight: Theme.titleWeight
                roundness: Theme.titleRoundness
                elide: Text.ElideRight
            }

            // Year, length, quality, rating
            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: {
                    const i = root.item;
                    if (!i)
                        return "";
                    const parts = [i.year || ""];
                    if (root.series) {
                        parts.push(`${root.seasons.length} ${root.seasons.length === 1 ? "season" : "seasons"}`, `${i.episodes.length} episodes`);
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
                    if (i.rating)
                        parts.push(`★ ${i.rating}`);
                    return parts.filter(x => x !== "").join("  ·  ");
                }
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            // Genres, as chips
            Row {
                topPadding: 4
                spacing: 6
                visible: (root.item?.genres?.length ?? 0) > 0

                Repeater {
                    model: root.item?.genres ?? []

                    Rectangle {
                        required property string modelData

                        width: genre.implicitWidth + 18
                        height: 22
                        radius: 11
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

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                topPadding: 6
                visible: text !== ""
                text: root.item?.tagline ?? ""
                color: Theme.on_surface
                font.pixelSize: 13
                font.italic: true
                elide: Text.ElideRight
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                topPadding: 2
                text: root.item?.overview ?? ""
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
                maximumLineCount: root.series ? 2 : 4
                elide: Text.ElideRight
                lineHeight: 1.15
            }

            // The languages it plays in
            Row {
                topPadding: 4
                spacing: 6

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
                        const a = t?.audio ? Languages.name(t.audio) : audio.length === 1 ? Languages.name(audio[0]) : `Automatic (${audio.length} languages)`;
                        const s = t?.subs ? Languages.name(t.subs) : subs.length === 0 ? "None" : `Automatic (${subs.length} languages)`;
                        return `Audio: ${a}    Subtitles: ${s}`;
                    }
                    color: Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }
            }

            Row {
                topPadding: 8
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
        }
    }

    // A series' seasons, the one on show filled; [ and ] change it
    Row {
        id: seasonRow

        anchors.top: header.bottom
        anchors.topMargin: 14
        x: 16
        spacing: 4
        visible: root.series && root.seasons.length > 1

        Repeater {
            model: seasonRow.visible ? root.seasons : []

            Rectangle {
                id: chip

                required property int modelData
                readonly property bool on: modelData === root.season

                width: chipLabel.implicitWidth + 24
                height: 30
                radius: 15
                color: on ? Theme.secondary_container : chipMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"

                Label {
                    id: chipLabel

                    anchors.centerIn: parent
                    text: `Season ${chip.modelData}`
                    color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                    font.pixelSize: 12
                    font.weight: chip.on ? Font.DemiBold : Font.Medium
                }

                MouseArea {
                    id: chipMouse

                    anchors.fill: parent
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

    // A movie's details, under its header
    Grid {
        anchors.top: header.bottom
        anchors.topMargin: 22
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
                height: 64
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
