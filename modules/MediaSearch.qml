import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"

// Search Jackett for movies, anime, Hindi films or ebooks (whichever the
// caller opened it for, named in the title), then download the pick with
// Transmission or stream it with peerflix. Opened for "play", it plays a
// pasted URL or magnet link instead, starting from a link on the clipboard. The Jackett side is
// jackett-search's --json, --add and --stream, shared with the rofi menus
// of the old setup; this is the window.
//
// It opens at the bottom centre at the rofi menu's size, widening and
// growing only once there are results.
//
// Keyboard first, vim style. It opens typing (the field outlined): Enter
// searches. Results take the keys from the field: j/k (or the arrows),
// gg/G, Ctrl+d/Ctrl+u move, Enter or l downloads, s streams, / or i go back
// to the query, q or Esc closes. Esc while typing goes back to the results,
// or closes when there are none. A search runs for as long as Jackett takes (often half a
// minute), with a travelling wave below the field meanwhile.
Scope {
    id: root

    readonly property string menus: Quickshell.env("HOME") + "/.local/bin/menus"
    readonly property var kinds: [
        {
            id: "movies",
            label: "Movies",
            script: "movie-search",
            noun: "movies"
        },
        {
            id: "anime",
            label: "Anime",
            script: "anime-search",
            noun: "anime"
        },
        {
            id: "hindi",
            label: "Hindi",
            script: "hindi-movie-search",
            noun: "Hindi movies"
        },
        {
            id: "books",
            label: "Books",
            script: "ebook-search",
            noun: "ebooks"
        },
        // Not a search: play what's pasted, as play-video does
        {
            id: "play",
            label: "Play",
            play: true
        }
    ]
    property int kind: 0
    readonly property var current: kinds[kind]

    property bool open: false
    // Typing the query, rather than moving through the results
    property bool typing: true
    // "idle", "searching", "done" or "error"
    property string phase: "idle"
    property string message
    // What the results on show were searched for
    property string searched
    property var results: []
    property var job: null

    function show(id) {
        const i = kinds.findIndex(k => k.id === id);
        if (i >= 0 && i !== kind) {
            kind = i;
            reset();
            field.text = "";
        }
        // A link already copied is likely what's to be played. Read with
        // wl-paste: Qt can't read the clipboard before the window has focus.
        if (current.play) {
            field.text = "";
            clipboard.running = true;
        }
        open = true;
        type(true);
    }

    // Into the field (all of the query selected, to type over it, or the
    // cursor at its end, to change it), or back to the results
    function type(on, selectAll) {
        typing = on || results.length === 0 || !!current.play;
        if (typing) {
            field.forceActiveFocus();
            if (selectAll !== false)
                field.selectAll();
            else
                field.cursorPosition = field.text.length;
        } else {
            keys.forceActiveFocus();
        }
    }

    // A magnet link streams through peerflix, anything else goes to mpv
    // (which hands web pages to yt-dlp)
    function play() {
        const url = field.text.trim();
        if (url === "")
            return;
        Quickshell.execDetached(url.startsWith("magnet:") ? ["peerflix", "--mpv", "--", url] : ["mpv", "--", url]);
        hide();
    }

    function hide() {
        open = false;
    }

    function reset() {
        job?.cancel();
        job = null;
        results = [];
        searched = "";
        phase = "idle";
    }

    function search() {
        const query = field.text.trim();
        if (query === "")
            return;
        job?.cancel();
        searched = query;
        phase = "searching";
        job = jobComponent.createObject(root, {
            command: [`${menus}/${current.script}`, "--json", query]
        });
    }

    function finished(which, code, out, err) {
        if (which !== job)
            return;
        job = null;
        if (code !== 0) {
            phase = "error";
            message = err.trim().split("\n").pop() || `Search failed (exit ${code})`;
            return;
        }
        try {
            results = JSON.parse(out);
        } catch (e) {
            phase = "error";
            message = "Couldn't read the results";
            return;
        }
        phase = "done";
        list.currentIndex = 0;
        // The keys move to the results
        if (open)
            type(false);
    }

    // Download, or stream, the result at index
    function act(index, stream) {
        const r = results[index];
        if (!r)
            return;
        // Quietly: the bar's downloads ring is the confirmation (a failure
        // still notifies)
        Quickshell.execDetached(["env", "JACKETT_QUIET=1", `${menus}/${current.script}`, stream ? "--stream" : "--add", r.magnet_uri, r.title]);
        // Have it show there as soon as Transmission has it
        if (!stream)
            Transmission.expect();
        hide();
    }

    function size(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes, unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return unit === 0 ? `${value} B` : `${value.toFixed(1)} ${units[unit]}`;
    }

    Process {
        id: clipboard

        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                const copied = text.trim();
                if (root.current.play && field.text === "" && /^(https?:\/\/|magnet:)\S+$/.test(copied)) {
                    field.text = copied;
                    field.selectAll();
                }
            }
        }
    }

    // One search, its own process so a newer one can simply replace it
    Component {
        id: jobComponent

        Process {
            id: proc

            property string out
            property string err
            property int code: -1
            property int pending: 3

            function cancel() {
                running = false;
                destroy();
            }

            function done() {
                if (--pending === 0) {
                    root.finished(proc, code, out, err);
                    destroy();
                }
            }

            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    proc.out = text;
                    proc.done();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    proc.err = text;
                    proc.done();
                }
            }
            onExited: code => {
                proc.code = code;
                proc.done();
            }
        }
    }

    PanelWindow {
        id: window

        // Spring open upwards, fold back quicker; shape only, see
        // Dropdown on why nothing here fades
        property real reveal: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished; flipping
        // with root.open alone would unmap it for a frame as closing starts
        visible: false
        // Its own name, so Hyprland can blur it but leave its layer
        // animations out: this surface covers the screen (to catch clicks
        // outside), and its slide would carry the whole thing off
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

            readonly property bool grown: root.phase === "done" && root.results.length > 0
            // The rofi movie search's size until there are results to show
            property real fullHeight: grown ? content.y + content.implicitHeight + 20 : 157

            // Bottom centre, where the rofi menus open, growing upwards
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: grown ? 820 : 500
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            Behavior on fullHeight {
                enabled: root.open && !openAnim.running
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }
            Behavior on width {
                enabled: root.open && !openAnim.running
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            // Swallow clicks on the panel itself
            MouseArea {
                anchors.fill: parent
            }

            ListKeys {
                id: listKeys

                list: list
            }

            // The results' keys, while not typing
            Item {
                id: keys

                Keys.onPressed: event => {
                    if (listKeys.handle(event)) {
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_L:
                        root.act(list.currentIndex, false);
                        break;
                    case Qt.Key_S:
                        root.act(list.currentIndex, true);
                        break;
                    case Qt.Key_Slash:
                        root.type(true);
                        break;
                    case Qt.Key_I:
                        root.type(true, false);
                        break;
                    case Qt.Key_Q:
                    case Qt.Key_Escape:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }

            Column {
                id: content

                x: 20
                y: 26
                width: parent.width - 40
                spacing: 14

                // Title, as the rofi menus have: what's searched, or how the
                // search went
                Item {
                    width: parent.width
                    height: 34

                    Label {
                        id: title

                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        text: {
                            switch (root.phase) {
                            case "searching":
                                return `Searching ${root.current.noun}…`;
                            case "error":
                                return root.message;
                            case "done":
                                if (root.results.length === 0)
                                    return `No ${root.current.noun} found`;
                            }
                            return root.current.play ? "Play" : `Search ${root.current.noun}`;
                        }
                        width: Math.min(implicitWidth, parent.width - 2)
                        elide: Text.ElideRight
                        color: root.phase === "error" ? Theme.error : Theme.primary
                        // rofi's 20 pt
                        font.pixelSize: 26
                        font.weight: Theme.titleWeight
                        roundness: Theme.titleRoundness
                    }

                }

                // Search field, outlined while typing
                Rectangle {
                    width: parent.width
                    height: 46
                    border.width: root.typing && root.open ? 2 : 0
                    border.color: Theme.primary

                    // The wave while Jackett searches, in the room below the
                    // field rather than making more
                    LinearProgress {
                        anchors.top: parent.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        visible: root.phase === "searching"
                        indeterminate: true
                        wavy: true
                        thickness: 5
                    }
                    radius: Theme.radius
                    color: Theme.surface_container_highest

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        name: root.current.play ? "media_play_arrow" : "search"
                        size: 20
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
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        clip: true

                        // Typing; these search, play or leave
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                if (root.results.length > 0 && !root.current.play)
                                    root.type(false);
                                else
                                    root.hide();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                if (root.current.play)
                                    root.play();
                                // The same query again just goes back to its results
                                else if (text.trim() !== root.searched || root.results.length === 0)
                                    root.search();
                                else
                                    root.type(false);
                                break;
                            case Qt.Key_Down:
                                root.type(false);
                                break;
                            case Qt.Key_J:
                                if (!ctrl)
                                    return;
                                root.type(false);
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
                        text: root.current.play ? "Paste a URL or magnet link…" : "Search…"
                        color: Theme.on_surface_variant
                        font.pixelSize: 16
                        font.weight: Font.Normal
                    }

                }

                // Results
                ListView {
                    id: list

                    readonly property real rowHeight: 64
                    readonly property int shownRows: Math.min(count, 7)

                    visible: root.phase === "done" && count > 0
                    width: parent.width
                    height: shownRows * rowHeight + Math.max(0, shownRows - 1) * spacing
                    spacing: 2
                    clip: true
                    model: root.phase === "done" ? root.results : []
                    boundsBehavior: Flickable.StopAtBounds
                    // Keep the current row in view as the keys move it
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    // The pick's fill slides from row to row, above the rows'
                    // backgrounds and under their content
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 220
                    highlightMoveVelocity: -1
                    highlight: Rectangle {
                        radius: Theme.radius
                        color: Theme.secondary_container
                        opacity: list.currentItem?.opacity ?? 1
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: ListView.isCurrentItem
                        readonly property bool first: index === 0
                        readonly property bool last: index === list.count - 1

                        width: list.width
                        height: list.rowHeight

                        // The row's background, on a layer under the list's
                        // sliding highlight; it follows the row
                        Rectangle {
                            parent: list.contentItem
                            z: -1
                            x: row.x
                            y: row.y
                            width: row.width
                            height: row.height
                            opacity: row.opacity
                            topLeftRadius: row.first ? Theme.radius : 3
                            topRightRadius: row.first ? Theme.radius : 3
                            bottomLeftRadius: row.last ? Theme.radius : 3
                            bottomRightRadius: row.last ? Theme.radius : 3
                            color: Theme.surface_container_high
                        }

                        // Tracker, as a short code
                        Rectangle {
                            id: badge

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 40
                            radius: 8
                            color: Theme.primary_container

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.tracker
                                color: Theme.on_primary_container
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            anchors.left: badge.right
                            anchors.leftMargin: 14
                            anchors.right: stats.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                anchors.verticalCenter: undefined
                                width: parent.width
                                text: row.modelData.title
                                color: Theme.on_surface
                                font.pixelSize: 15
                                elide: Text.ElideRight
                            }

                            Label {
                                anchors.verticalCenter: undefined
                                width: parent.width
                                text: `${root.size(row.modelData.size_bytes)} · ${row.modelData.indexer}`
                                color: Theme.on_surface_variant
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        // Seeders and leechers, then the actions for the
                        // current row
                        Row {
                            id: stats

                            anchors.right: actions.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Row {
                                spacing: 2

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "arrow_upward"
                                    size: 14
                                    color: Theme.primary
                                }

                                Text {
                                    width: 40
                                    text: row.modelData.seeders
                                    color: Theme.on_surface
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }

                            Row {
                                spacing: 2

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "arrow_downward"
                                    size: 14
                                    color: Theme.on_surface_variant
                                }

                                Text {
                                    width: 40
                                    text: row.modelData.leechers
                                    color: Theme.on_surface_variant
                                    font.family: Theme.monoFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Row {
                            id: actions

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            // Kept in the layout so the numbers don't shift
                            opacity: row.isCurrent || rowMouse.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            IconButton {
                                implicitWidth: 40
                                implicitHeight: 40
                                icon: "media_play_arrow"
                                iconSize: 20
                                color: Theme.on_surface_variant
                                onClicked: root.act(row.index, true)
                            }

                            IconButton {
                                implicitWidth: 40
                                implicitHeight: 40
                                icon: "download"
                                iconSize: 20
                                color: Theme.primary
                                onClicked: root.act(row.index, false)
                            }
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: root.act(row.index, false)
                        }

                        MenuReveal {
                            target: row
                            shown: root.phase === "done"
                            index: Math.min(row.index, 8)
                        }
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call search open movies` (or anime, hindi, books, play)
    IpcHandler {
        target: "search"

        function open(kind: string): void {
            root.show(kind);
        }

        function close(): void {
            root.hide();
        }
    }
}
