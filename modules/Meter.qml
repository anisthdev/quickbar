import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// A ring of how much of something is used (or done, or left), in the
// caller's colour with the caller's icon inside: Claude Code's usage, or
// anything else that writes the file. Hover for the numbers, click for a
// card with each of them. Hidden while there's nothing to show.
//
// Any tool can feed one: it writes ~/.cache/quickbar/meters/<source>.json,
//
//   {"items": [{"label": "5-hour", "progress": 0.23, "text": "23% used",
//               "resets_at": EPOCH, "reset_progress": 0}, ...]}
//
// progress from 0 to 1; text (optional) is how the tooltip and card say
// it; once resets_at (optional) passes, the item counts as reset_progress
// (say, a usage window that's unused again) until the tool writes anew.
// The bar shows the first item, or with pick "highest" or "lowest" the one
// furthest along or least. With "pids" (optional, process ids), it shows
// only while one of them runs. scripts/claude-usage writes Claude Code's.
Pill {
    id: root

    // The file's name, without .json
    required property string source
    // An icon from icons/, inside the ring
    required property string icon
    property string title: source
    // The ring's and the card's bars' colour
    property color color: Theme.primary
    // The ring's size; the icon is half of it
    property real size: 28
    // "first", "highest" or "lowest"
    property string pick: "first"

    readonly property string path: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/quickbar/meters/${source}.json`
    property var data: null
    // Now, a minute at a time, for the resets
    property double now: Date.now()
    // One of the file's pids runs (or it has none)
    property bool running: true
    readonly property var pids: data?.pids ?? []

    // The items, the resets worked in
    readonly property var items: (data?.items ?? []).map(item => {
            const reset = item.resets_at && item.resets_at * 1000 <= now && item.reset_progress !== undefined;
            const progress = Math.max(0, Math.min(1, reset ? item.reset_progress : item.progress ?? 0));
            return Object.assign({}, item, {
                progress: progress,
                reset: reset,
                text: reset ? "Reset" : item.text || `${Math.round(progress * 100)}%`
            });
        })
    readonly property var shown: {
        if (pick === "first")
            return items[0] ?? null;
        const higher = (a, b) => pick === "highest" ? a.progress > b.progress : a.progress < b.progress;
        return items.reduce((best, item) => !best || higher(item, best) ? item : best, null);
    }

    // "in 2 h 10 min", "in 3 d 4 h"
    function until(epoch) {
        const minutes = Math.max(0, Math.round((epoch * 1000 - now) / 60000));
        if (minutes < 60)
            return `in ${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return minutes % 60 ? `in ${hours} h ${minutes % 60} min` : `in ${hours} h`;
        return hours % 24 ? `in ${Math.floor(hours / 24)} d ${hours % 24} h` : `in ${Math.floor(hours / 24)} d`;
    }

    // "14:20" today, "Fri 14:20" later
    function clock(epoch) {
        const at = new Date(epoch * 1000);
        const time = at.toLocaleTimeString(Qt.locale(), "HH:mm");
        return at.toDateString() === new Date(now).toDateString() ? time : `${at.toLocaleDateString(Qt.locale(), "ddd")} ${time}`;
    }

    // What's said of an item when it resets
    function resets(item) {
        if (item.reset || !item.resets_at)
            return "";
        return `resets ${until(item.resets_at)}, ${clock(item.resets_at)}`;
    }

    padding: 6
    visible: items.length > 0 && running
    clickable: true
    onClicked: card.toggle()

    FileView {
        id: file

        path: root.path
        watchChanges: true
        // Not there until the tool first writes it
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                root.data = null;
            }
        }
        onLoadFailed: root.data = null
    }

    onPidsChanged: checkPids()

    function checkPids() {
        if (pids.length === 0)
            running = true;
        else
            checker.running = true;
    }

    // Whether any of the pids still runs
    Process {
        id: checker

        command: ["sh", "-c", 'for p; do kill -0 "$p" 2>/dev/null && exit 0; done; exit 1', "sh", ...root.pids.map(String)]
        onExited: code => root.running = code === 0
    }

    Timer {
        interval: 5000
        running: root.pids.length > 0
        repeat: true
        onTriggered: root.checkPids()
    }

    // The resets come due, and a file replaced (not written in place) is
    // read again
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now();
            file.reload();
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: root.size
        height: root.size

        CircularProgress {
            anchors.centerIn: parent
            size: root.size
            thickness: 3
            progress: root.shown?.progress ?? 0
            color: root.color
            trackColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.25)
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: root.size / 2
            color: root.color
        }
    }

    Tooltip {
        owner: root
        shown: root.hovered && !card.open
        text: root.title
        description: root.items.map(item => [`${item.label}: ${item.text}`, root.resets(item)].filter(s => s).join(" · ")).join("\n")
    }

    MeterCard {
        id: card

        owner: root
        meter: root
        onOpenChanged: if (open)
            root.now = Date.now()
    }
}
