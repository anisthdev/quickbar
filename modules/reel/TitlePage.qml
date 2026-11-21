import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../.."
import "../../components"

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
    // The season on show
    property int season: 0
    // Its seasons, what has aired, its scores, its facts in words
    readonly property TitleInfo info: TitleInfo {
        item: root.item
        season: root.season
    }
    readonly property var seasons: info.seasons
    readonly property var have: info.have
    readonly property var allSeasons: info.allSeasons
    readonly property var shown: info.shown
    readonly property var ratings: info.ratings
    readonly property var air: info.air
    // The episode picked, as an index into the series' episodes
    readonly property int pick: shown[episodes.currentIndex]?.index ?? -1
    readonly property var next: info.next

    // Enter on an episode or a button; index into the series' episodes, -1
    // for a movie
    signal play(int index, bool fromStart)
    signal action(string id)
    signal back

    function airedIn(n) {
        return info.airedIn(n);
    }

    function code(e) {
        return info.code(e);
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
        list.push({
            id: "delete",
            label: "Delete  D",
            icon: "delete",
            primary: false
        });
        return list;
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
                    text: root.info.kindLine
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
                text: root.info.summary
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
                text: root.info.languageLine
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
            model: root.info.details

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
