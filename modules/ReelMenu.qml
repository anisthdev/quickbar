import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."
import "../components"

// The video library as a menu, beside Reel's full-screen window: one
// library at a time (Movies, Series or Anime) as a strip of posters across
// the middle of the screen, from side to side, as the wallpaper picker
// does; each with how far it's been watched in a bar below, and its title.
// A series' card says which episode is next. Picking plays in mpv, through
// Reel: a movie resumes where it stopped, a series carries on from the
// next episode (the first, if it's new), and the menu closes.
//
// Keys: h/l (or j/k, the arrows) move, gg/G go to the first and last, m, s
// and a open Movies, Series and Anime, Tab and Shift+Tab go round them,
// Enter or Space plays, q or Esc closes. / or i (or a click) focuses the
// filter, as in the other menus: typing filters the library by title,
// Enter plays, Esc goes back to the posters keeping the filter, and Esc
// there clears it. The mouse wheel moves; a click picks, a click on the
// pick plays.
Scope {
    id: root

    // Reel: the library, its progress and mpv
    required property var reel

    readonly property real posterWidth: 220
    readonly property real posterHeight: 330
    readonly property real grownScale: 1.08

    // The libraries, by reel's row (category) names
    readonly property var tabs: [
        {
            key: "m",
            label: "Movies",
            category: "Movies"
        },
        {
            key: "s",
            label: "Series",
            category: "TV"
        },
        {
            key: "a",
            label: "Anime",
            category: "Anime"
        }
    ]

    property bool open: false
    property int tab: 0
    property bool filtering: false
    // The library's titles, recently played first, matching the filter
    // ranked as the launcher menus do: the start of the title, then the
    // start of a word in it, then anywhere in it
    readonly property var items: {
        const all = reel.rows.find(r => r.name === tabs[tab].category)?.items ?? [];
        const q = field.text.trim().toLowerCase();
        if (q === "")
            return all;
        const rank = item => {
            const title = item.title.toLowerCase();
            if (title.startsWith(q))
                return 0;
            if (title.split(/[\s\-_.:]+/).some(w => w.startsWith(q)))
                return 1;
            return title.includes(q) ? 2 : -1;
        };
        return all.map((item, i) => ({
                    item,
                    i,
                    r: rank(item)
                })).filter(m => m.r >= 0).sort((a, b) => a.r - b.r || a.i - b.i).map(m => m.item);
    }
    readonly property var current: items[strip.currentIndex] ?? null

    function show() {
        reel.load();
        field.text = "";
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

    function switchTo(index) {
        tab = (index + tabs.length) % tabs.length;
        strip.currentIndex = 0;
        strip.positionViewAtBeginning();
    }

    function nextOf(item) {
        return item.kind === "series" ? item.episodes[item.next] ?? null : null;
    }

    // The bar: a movie's position; a series' episodes watched, the one
    // going counting for its part
    function progressOf(item) {
        if (item.kind === "movie")
            return item.watched ? 1 : item.progress;
        const done = item.episodes.filter(e => e.watched).length;
        const going = nextOf(item)?.progress ?? 0;
        return (done + going) / Math.max(1, item.episodes.length);
    }

    // Under the title: where it's at
    function statusOf(item) {
        if (item.kind === "movie") {
            if (item.position > 0)
                return reel.left(item);
            if (item.watched)
                return "Watched";
            return [item.year ?? "", item.duration ? reel.runtime(item.duration) : ""].filter(b => b !== "").join("  ·  ");
        }
        const next = nextOf(item);
        if (next)
            return `${reel.code(next)}  ·  ${item.next + 1} of ${item.episodes.length}`;
        if (item.lastPlayed > 0)
            return `Watched  ·  ${item.episodes.length} episodes`;
        return `New  ·  ${item.episodes.length} episodes`;
    }

    // Seen to the end: a movie, or every episode of a series
    function watchedAll(item) {
        return item.kind === "movie" ? item.watched : item.episodes.every(e => e.watched);
    }

    // A movie resumes; a series carries on from its next episode, or
    // starts at the first
    function play(index) {
        const item = items[index];
        if (!item)
            return;
        reel.play(item, item.kind === "movie" ? 0 : Math.max(0, item.next));
        hide();
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

            readonly property real fullHeight: strip.y + strip.height + 20

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
                    const g = event.key === Qt.Key_G && event.text === "g";
                    if (!g)
                        pendingG = false;
                    const tab = root.tabs.findIndex(t => t.key === event.text);
                    if (tab >= 0) {
                        root.switchTo(tab);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
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
                    case Qt.Key_Tab:
                        root.switchTo(root.tab + 1);
                        break;
                    case Qt.Key_Backtab:
                        root.switchTo(root.tab - 1);
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
            }

            // The title and the libraries, with their keys
            Row {
                id: header

                x: 20
                y: 22
                height: 34
                spacing: 18

                Label {
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: "Reel"
                    color: Theme.primary
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: root.tabs

                        delegate: Rectangle {
                            id: chip

                            required property var modelData
                            required property int index
                            readonly property bool on: index === root.tab

                            width: chipRow.implicitWidth + 28
                            height: 34
                            radius: 17
                            color: on ? Theme.secondary_container : Theme.surface_container_high

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 8

                                Label {
                                    text: chip.modelData.label
                                    color: chip.on ? Theme.on_secondary_container : Theme.on_surface_variant
                                    font.pixelSize: 15
                                }

                                Label {
                                    text: chip.modelData.key
                                    color: chip.on ? Theme.on_secondary_container : Theme.outline
                                    opacity: 0.7
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 13
                                }
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

            // The pick's details: year, rating, genres
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: header.verticalCenter
                text: {
                    const i = root.current;
                    if (!i)
                        return "";
                    const bits = [];
                    if (i.year)
                        bits.push(i.year);
                    if (i.rating)
                        bits.push(`★ ${i.rating.toFixed(1)}`);
                    if (i.genres?.length)
                        bits.push(i.genres.slice(0, 3).join(", "));
                    return bits.join("  ·  ");
                }
                color: Theme.on_surface_variant
                font.pixelSize: 15
            }

            ListView {
                id: strip

                // A card: the poster with room above for it to grow, then
                // the bar and two lines
                readonly property real cardHeight: root.posterHeight * root.grownScale + 12 + 6 + 62

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
                    readonly property var item: modelData
                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property bool grown: isCurrent && window.settled

                    width: root.posterWidth
                    height: strip.cardHeight

                    // Grows upward, clear of the bar and title below
                    Item {
                        id: poster

                        anchors.bottom: bar.top
                        anchors.bottomMargin: 12
                        width: root.posterWidth
                        height: root.posterHeight
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
                            color: Theme.surface_container_high

                            // No poster: the title, in its place
                            Label {
                                anchors.verticalCenter: undefined
                                anchors.fill: parent
                                anchors.margins: 16
                                visible: !card.item.poster
                                text: card.item.title
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                color: Theme.on_surface_variant
                                font.pixelSize: 18
                                font.weight: Theme.titleWeight
                            }

                            Image {
                                anchors.fill: parent
                                // Only while shown, so closing frees the
                                // decoded posters
                                source: window.visible && card.item.poster ? "file://" + card.item.poster : ""
                                sourceSize.width: 440
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                            }

                            // Darkens the top, so the watched chip reads
                            // on any picture
                            Rectangle {
                                visible: watchedChip.visible
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 80
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: Qt.rgba(0, 0, 0, 0.7)
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "transparent"
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

                        // Watched: a chip in the corner, as Reel's cards have
                        Rectangle {
                            id: watchedChip

                            visible: root.watchedAll(card.item)
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: watchedRow.implicitWidth + 18
                            height: 26
                            radius: 13
                            // Solid, to read on any picture
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)
                            opacity: card.isCurrent ? 1 : 0.7

                            Row {
                                id: watchedRow

                                anchors.centerIn: parent
                                spacing: 4

                                Icon {
                                    name: "task_alt"
                                    size: 16
                                    color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                                }

                                Label {
                                    text: "Watched"
                                    color: Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1)
                                    font.pixelSize: 12
                                    font.weight: Theme.titleWeight
                                }
                            }
                        }
                    }

                    // How far it's been watched
                    Rectangle {
                        id: bar

                        anchors.bottom: lines.top
                        anchors.bottomMargin: 10
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.surface_container_highest

                        Rectangle {
                            readonly property real progress: Math.min(1, root.progressOf(card.item))

                            visible: progress > 0
                            width: Math.max(height, parent.width * progress)
                            height: parent.height
                            radius: 3
                            color: card.isCurrent ? Theme.primary : Theme.outline

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
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
                            text: card.item.title
                            elide: Text.ElideRight
                            color: card.isCurrent ? Theme.on_surface : Theme.on_surface_variant
                            font.pixelSize: 16
                            font.weight: Theme.titleWeight
                        }

                        Label {
                            anchors.verticalCenter: undefined
                            width: parent.width
                            text: root.statusOf(card.item)
                            elide: Text.ElideRight
                            color: card.isCurrent ? Theme.primary : Theme.on_surface_variant
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.isCurrent ? root.play(card.index) : strip.currentIndex = card.index
                    }
                }
            }

            Label {
                anchors.verticalCenter: undefined
                anchors.centerIn: strip
                visible: root.items.length === 0
                text: !root.reel.library ? "Loading the library…" : field.text.trim() !== "" ? `Nothing in ${root.tabs[root.tab].label} matches` : `Nothing in ${root.tabs[root.tab].label} yet`
                color: Theme.on_surface_variant
                font.pixelSize: 20
            }
        }
    }

    // `qs -p <dir> ipc call reelmenu toggle`, e.g. from a key
    IpcHandler {
        target: "reelmenu"

        function toggle(): void {
            root.toggle();
        }
    }
}
