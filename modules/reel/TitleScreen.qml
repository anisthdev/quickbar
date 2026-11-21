import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../.."
import "../../components"
import "Plan.js" as Plan

// A title's page in the video window, as a streaming app's: the whole
// window in the title's own colours (Tint), its backdrop across the top
// right fading into them, and over it what it is: its logo (or name), its
// facts, whether a show is on the air, its scores and story; a wide Watch
// pill saying what it'll do, and the other things to do beside it. Along
// the foot, a series' seasons and the season's episodes as cards across;
// a movie's details. The menu drives its keys through `list`, as it does
// TitlePage's (the same API): h/l or j/k move along the episodes, [ and ]
// change season.
Item {
    id: root

    property var item: null
    property bool live: true
    readonly property bool series: item?.kind === "series"
    readonly property alias list: episodes
    property int season: 0
    readonly property TitleInfo info: TitleInfo {
        item: root.item
        season: root.season
    }
    readonly property var shown: info.shown
    // The episode picked, as an index into the series' episodes
    readonly property int pick: shown[episodes.currentIndex]?.index ?? -1
    readonly property Tint tint: Tint {
        source: root.live ? root.item?.backdrop ?? "" : ""
    }

    signal play(int index, bool fromStart)
    signal action(string id)
    signal back

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
        const seasons = info.seasons;
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

    // What there is to do besides Watch, with their keys
    readonly property var actions: {
        const i = item;
        if (!i)
            return [];
        const list = [];
        if (series) {
            list.push({
                id: "upto",
                label: "Seen up to here",
                key: "W",
                icon: "task_alt",
                lit: false
            });
        } else {
            list.push({
                id: "watched",
                label: i.watched ? "Watched" : "Watched it?",
                key: "w",
                icon: "task_alt",
                lit: i.watched
            });
            if (i.position > 0)
                list.push({
                    id: "start",
                    label: "Start over",
                    key: "P",
                    icon: "restart_alt",
                    lit: false
                });
        }
        list.push({
            id: "tracks",
            label: "Languages",
            key: "t",
            icon: "translate",
            lit: !!(i.tracks?.audio || i.tracks?.subs)
        });
        list.push({
            id: "delete",
            label: "Delete",
            key: "D",
            icon: "delete",
            lit: false
        });
        return list;
    }

    // The page in the title's colours, deepening down
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(root.tint.glow, 0.94)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(root.tint.glow, 0.82)
            }
        }
    }

    // The backdrop across the whole top, down to the info, fading into the
    // page by a mask (the page is translucent, so a gradient to its colour
    // would leave an edge); darkened behind the words on its left
    Item {
        id: backdropBox

        width: parent.width
        height: Math.max(width * 9 / 16 * 0.85, about.y + about.height * 0.5)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: downMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Image {
            anchors.fill: parent
            source: root.live && root.item?.backdrop ? `file://${root.item.backdrop}` : ""
            sourceSize.width: 1920
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0

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
                    color: Qt.alpha(root.tint.glow, 0.9)
                }
                GradientStop {
                    position: Math.min(0.6, (about.x + about.width) / backdropBox.width)
                    color: Qt.alpha(root.tint.glow, 0.45)
                }
                GradientStop {
                    position: Math.min(0.85, (about.x + about.width) / backdropBox.width + 0.2)
                    color: "transparent"
                }
            }
        }
    }

    Rectangle {
        id: downMask

        width: backdropBox.width
        height: backdropBox.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop {
                position: 0.5
                color: "white"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    // Back
    Rectangle {
        x: 28
        y: 22
        width: backRow.implicitWidth + 26
        height: 34
        radius: 17
        color: backMouse.containsMouse ? Qt.alpha(textColor, 0.16) : Qt.alpha(textColor, 0.08)

        readonly property color textColor: Theme.light ? "black" : "white"

        Row {
            id: backRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                name: "keyboard_arrow_left"
                size: 18
                color: Theme.on_surface
            }

            Label {
                text: "Back"
                color: Theme.on_surface
                font.pixelSize: 13
            }

            Label {
                text: "Esc"
                color: Theme.on_surface_variant
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: backMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    // What it is, over the backdrop's left
    Column {
        id: about

        x: 40
        anchors.bottom: lower.top
        anchors.bottomMargin: 26
        width: Math.min(parent.width * 0.52, 600)
        spacing: 10

        Label {
            anchors.verticalCenter: undefined
            text: root.info.kindLine.toUpperCase()
            color: Theme.on_surface_variant
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        // The logo where it has one (sized from logo_size before it
        // loads), else the name
        Item {
            id: titleBox

            readonly property real aspect: root.item?.logo_size?.[1] > 0 ? root.item.logo_size[0] / root.item.logo_size[1] : 0
            readonly property real logoHeight: aspect > 0 ? Math.min(root.height > 640 ? 120 : 84, Math.min(parent.width, 420) / aspect) : 0
            readonly property bool logo: !!root.item?.logo_image && aspect > 0 && logoImage.status !== Image.Error

            width: parent.width
            height: logo ? logoHeight : nameText.implicitHeight

            Image {
                id: logoImage

                anchors.bottom: parent.bottom
                visible: titleBox.logo
                height: titleBox.logoHeight
                width: height * titleBox.aspect
                source: root.live && root.item?.logo_image ? `file://${root.item.logo_image}` : ""
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Label {
                id: nameText

                anchors.verticalCenter: undefined
                anchors.bottom: parent.bottom
                visible: !titleBox.logo
                width: parent.width
                text: root.item?.title ?? ""
                color: Theme.on_surface
                font.pixelSize: 40
                font.weight: Theme.titleWeight
                roundness: Theme.titleRoundness
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            text: [root.info.summary, (root.item?.genres ?? []).slice(0, 3).join(", ")].filter(x => x).join("  ·  ")
            color: Theme.on_surface
            opacity: 0.85
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        // On the air or not, then the scores
        Row {
            spacing: 18
            visible: root.info.air !== null || root.info.ratings.length > 0

            Rectangle {
                id: airBadge

                anchors.verticalCenter: parent.verticalCenter
                visible: root.info.air !== null
                width: airRow.implicitWidth + 20
                height: 24
                radius: 12
                color: root.info.air?.state === "airing" ? root.tint.accent : Qt.alpha(Theme.on_surface, 0.12)

                readonly property color ink: root.info.air?.state === "airing" ? root.tint.onAccent : Theme.on_surface

                Row {
                    id: airRow

                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.info.air?.state === "airing"
                        width: 7
                        height: 7
                        radius: 3.5
                        color: airBadge.ink
                    }

                    Label {
                        text: root.info.air?.label ?? ""
                        color: airBadge.ink
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Label {
                        visible: text !== ""
                        text: root.info.air?.detail ?? ""
                        color: airBadge.ink
                        opacity: 0.8
                        font.pixelSize: 12
                    }
                }
            }

            Repeater {
                model: root.info.ratings

                RatingBadge {
                    required property var modelData

                    source: modelData.source
                    score: modelData.score
                }
            }
        }

        Label {
            anchors.verticalCenter: undefined
            width: parent.width
            visible: text !== "" && root.height > 560
            text: root.item?.overview ?? ""
            color: Theme.on_surface
            opacity: 0.8
            font.pixelSize: 14
            font.weight: Font.Normal
            wrapMode: Text.WordWrap
            maximumLineCount: root.height > 760 ? 4 : root.height > 660 ? 3 : 2
            elide: Text.ElideRight
            lineHeight: 1.25
        }

        // Watch, as a wide pill in the title's colour, and the rest beside it
        Row {
            topPadding: 8
            spacing: 10

            Rectangle {
                id: watch

                width: Math.max(260, watchText.implicitWidth + 96)
                height: 64
                radius: 32
                color: watchMouse.containsMouse ? Qt.lighter(root.tint.accent, 1.08) : root.tint.accent

                Rectangle {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: 24
                    color: Qt.alpha(root.tint.onAccent, 0.85)

                    Icon {
                        anchors.centerIn: parent
                        name: "media_play_arrow"
                        size: 26
                        color: root.tint.accent
                    }
                }

                Column {
                    id: watchText

                    x: 70
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Row {
                        spacing: 8

                        Label {
                            text: Plan.label(root.item)
                            color: root.tint.onAccent
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }

                        Label {
                            text: "p"
                            color: root.tint.onAccent
                            opacity: 0.55
                            font.family: Theme.monoFamily
                            font.pixelSize: 12
                        }
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        visible: text !== ""
                        width: Math.min(implicitWidth, 320)
                        text: Plan.sub(root.item)
                        color: root.tint.onAccent
                        opacity: 0.72
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: watchMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.action("play")
                }
            }

            Repeater {
                model: root.actions

                Rectangle {
                    id: actionButton

                    required property var modelData

                    width: Math.max(84, actionLabel.implicitWidth + 24)
                    height: 64
                    radius: 18
                    color: actionMouse.containsMouse ? Qt.alpha(Theme.on_surface, 0.12) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Icon {
                            anchors.verticalCenter: undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: actionButton.modelData.icon
                            size: 22
                            color: actionButton.modelData.lit ? root.tint.accent : Theme.on_surface
                            opacity: actionButton.modelData.lit ? 1 : 0.8
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Label {
                                id: actionLabel

                                text: actionButton.modelData.label
                                color: actionButton.modelData.lit ? root.tint.accent : Theme.on_surface
                                font.pixelSize: 12
                            }

                            Label {
                                text: actionButton.modelData.key
                                color: Theme.on_surface_variant
                                font.family: Theme.monoFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.action(actionButton.modelData.id)
                    }
                }
            }
        }
    }

    // Along the foot: a series' seasons and episodes, a movie's details
    Item {
        id: lower

        x: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: parent.width - 56
        height: root.series ? seasonRow.height + 10 + episodes.height : details.height + 12

        // Every season: the ones on disk to pick (with how many of the
        // aired episodes are here, when not all), the rest faint
        Row {
            id: seasonRow

            x: 18
            height: 32
            spacing: 4
            visible: root.series

            Repeater {
                model: root.series ? root.info.allSeasons : []

                Rectangle {
                    id: chip

                    required property int modelData
                    readonly property bool on: modelData === root.season
                    readonly property bool here: root.info.seasons.includes(modelData)
                    readonly property int count: root.info.have[modelData] ?? 0
                    readonly property int out: root.info.airedIn(modelData)

                    anchors.verticalCenter: parent.verticalCenter
                    width: chipLabel.implicitWidth + (root.info.allSeasons.length > 8 ? 18 : 26)
                    height: 32
                    radius: 16
                    color: on ? root.tint.accent : chipMouse.containsMouse && here ? Qt.alpha(Theme.on_surface, 0.1) : "transparent"
                    border.width: here || on ? 0 : 1
                    border.color: Qt.alpha(Theme.on_surface, 0.2)

                    Label {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: (root.info.allSeasons.length > 8 ? `S${chip.modelData}` : `Season ${chip.modelData}`) + (chip.here && chip.out > chip.count ? `  ${chip.count}/${chip.out}` : "")
                        color: chip.on ? root.tint.onAccent : Theme.on_surface
                        opacity: chip.here ? (chip.on ? 1 : 0.8) : 0.4
                        font.pixelSize: 12
                        font.weight: chip.on ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        enabled: chip.here
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.changeSeason(root.info.seasons.indexOf(chip.modelData) - root.info.seasons.indexOf(root.season))
                    }
                }
            }

            Label {
                leftPadding: 10
                visible: root.info.seasons.length > 1
                text: "[  ]"
                color: Theme.on_surface_variant
                font.family: Theme.monoFamily
                font.pixelSize: 12
            }
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: seasonRow.verticalCenter
            visible: root.series
            text: "Enter play  ·  P from its start  ·  w seen  ·  W up to here"
            color: Theme.on_surface_variant
            font.pixelSize: 11
        }

        // The season's episodes as cards across, the pick kept on its
        // episode as marks change
        ListView {
            id: episodes

            property string keptPath
            property var seen: null
            readonly property real cardWidth: Math.max(220, Math.min(280, (width - 24) / 4.2))

            anchors.top: seasonRow.bottom
            anchors.topMargin: 10
            width: parent.width
            height: cardWidth * 9 / 16 + 106
            visible: root.series
            orientation: ListView.Horizontal
            model: root.shown
            spacing: 18
            leftMargin: 18
            rightMargin: 18
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 18
            preferredHighlightEnd: width - 18
            highlightMoveDuration: 240
            highlightResizeDuration: 0
            highlight: Item {}

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

            delegate: Item {
                id: card

                required property var modelData
                required property int index
                readonly property var episode: modelData.episode
                readonly property bool current: index === episodes.currentIndex
                readonly property bool next: modelData.index === root.item.next && root.item.started

                width: episodes.cardWidth
                height: episodes.height

                // A little way down, with room above for the pick to grow
                // into (a horizontal list's topMargin doesn't)
                Item {
                    id: frame

                    y: 12
                    width: parent.width
                    height: width * 9 / 16
                    scale: card.current ? 1.05 : cardMouse.containsMouse ? 1.02 : 1
                    z: 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    ClippingRectangle {
                        id: still

                        anchors.fill: parent
                        radius: 14
                        color: Qt.alpha(Theme.on_surface, 0.08)

                        Label {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: card.episode.episode
                            color: Theme.on_surface_variant
                            font.family: Theme.monoFamily
                            font.pixelSize: 22
                        }

                        Image {
                            id: art

                            anchors.fill: parent
                            source: root.live && card.episode.still ? `file://${card.episode.still}` : ""
                            sourceSize.width: Math.ceil(card.width * 2)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? (card.episode.watched && !card.current ? 0.5 : 1) : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }

                        Rectangle {
                            visible: (card.episode.progress ?? 0) > 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 4
                            color: Qt.rgba(0, 0, 0, 0.5)

                            Rectangle {
                                width: parent.width * Math.min(1, card.episode.progress ?? 0)
                                height: parent.height
                                color: root.tint.accent
                            }
                        }
                    }

                    // Seen, or up next
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        visible: card.episode.watched || card.next
                        width: chipText.implicitWidth + 14
                        height: 22
                        radius: 8
                        color: card.episode.watched ? Qt.rgba(0, 0, 0, 0.6) : root.tint.accent

                        Label {
                            id: chipText

                            anchors.centerIn: parent
                            text: card.episode.watched ? "Seen" : card.episode.position > 0 ? "Carry on" : "Next"
                            color: card.episode.watched ? "white" : root.tint.onAccent
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // The pick's ring
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: still.radius + 4
                        color: "transparent"
                        border.width: 3
                        border.color: root.tint.accent
                        opacity: card.current ? 1 : card.next ? 0.35 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                Column {
                    anchors.top: frame.bottom
                    anchors.topMargin: 10
                    width: parent.width
                    spacing: 2

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        text: `${card.episode.episode}.  ${card.episode.title}`
                        color: Theme.on_surface
                        font.pixelSize: 13
                        font.weight: card.current ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        text: {
                            const e = card.episode;
                            if (e.position > 0)
                                return `${Plan.runtime(e.duration - e.position)} left`;
                            const d = e.air_date ? new Date(`${e.air_date}T00:00:00`) : null;
                            return [d && !isNaN(d) ? d.toLocaleDateString(Qt.locale(), "d MMM yyyy") : "", e.duration ? Plan.runtime(e.duration) : ""].filter(x => x).join("  ·  ");
                        }
                        color: card.episode.position > 0 ? root.tint.accent : Theme.on_surface_variant
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        visible: text !== ""
                        text: card.episode.overview ?? ""
                        color: Theme.on_surface_variant
                        opacity: 0.8
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: cardMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: episodes.currentIndex = card.index
                    onDoubleClicked: {
                        episodes.currentIndex = card.index;
                        root.play(card.modelData.index, false);
                    }
                }
            }
        }

        // A movie's details
        Row {
            id: details

            x: 12
            y: 6
            visible: !root.series && root.item !== null
            spacing: 12

            Repeater {
                model: root.series ? [] : root.info.details

                Rectangle {
                    required property var modelData

                    width: (lower.width - 24 - 36) / 4
                    height: 68
                    radius: Theme.radius
                    color: Qt.alpha(Theme.on_surface, 0.07)

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
}
