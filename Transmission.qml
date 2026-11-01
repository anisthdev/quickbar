pragma Singleton

import Quickshell
import QtQuick

// transmission-daemon's downloads, from its RPC: the unfinished torrents,
// newest first, and one that just finished. DownloadHub shows them, as
// Seedling's, with everyone else's downloads. Polls every 1.5 s while
// something downloads or someone is watching, every 10 s otherwise, and
// every half second for a moment after expect(), so a download added from
// the media search shows up at once.
Singleton {
    id: root

    readonly property string url: "http://127.0.0.1:9091/transmission/rpc"
    property string session

    // Unfinished torrents, newest first
    property var active: []
    // id → torrent, for lists keyed by id so their rows stay put (and their
    // waves keep going) across refreshes
    property var byId: ({})
    // A download that just finished, kept for a moment
    property var finished: null
    // Something (the downloads card) wants live numbers
    property bool watching: false
    // A download was just added and hasn't shown up yet
    property bool expecting: false
    property double expectedSince: 0

    // A download is on its way, e.g. from the media search
    function expect() {
        expectedSince = Date.now();
        expecting = true;
        expectTimeout.restart();
        refresh();
    }

    function rpc(method, args, done, retried) {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        if (session)
            xhr.setRequestHeader("X-Transmission-Session-Id", session);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            // The daemon hands out a session id on the first request. Qt's
            // XMLHttpRequest hides an error reply's headers, but the daemon
            // repeats the id in the page it sends along.
            if (xhr.status === 409 && !retried) {
                session = xhr.getResponseHeader("X-Transmission-Session-Id") || (xhr.responseText.match(/X-Transmission-Session-Id: (\w+)/)?.[1] ?? "");
                rpc(method, args, done, true);
                return;
            }
            if (xhr.status === 200 && done)
                done(JSON.parse(xhr.responseText).arguments);
        };
        xhr.send(JSON.stringify({
            method: method,
            arguments: args
        }));
    }

    function refresh() {
        rpc("torrent-get", {
            fields: ["id", "name", "status", "percentDone", "rateDownload", "eta", "addedDate", "sizeWhenDone", "leftUntilDone", "error", "errorString"]
        }, args => {
            const next = args.torrents.filter(t => t.percentDone < 1).sort((a, b) => b.addedDate - a.addedDate);
            // Something that was downloading and isn't any more, but is
            // still there: it finished
            const done = active.find(t => !next.some(n => n.id === t.id) && args.torrents.some(a => a.id === t.id && a.percentDone >= 1));
            if (done) {
                finished = done;
                finishedTimer.restart();
            }
            // addedDate is in seconds, and a little behind the click
            if (expecting && next.some(t => t.addedDate * 1000 >= expectedSince - 5000))
                expecting = false;
            const map = {};
            for (const t of next)
                map[t.id] = t;
            byId = map;
            active = next;
        });
    }

    // A torrent as one of DownloadHub's downloads: Seedling's, a click
    // opening Seedling on it
    function toDownload(t) {
        const states = ["paused", "verifying", "verifying", "queued", "downloading", "queued", "downloading"];
        const stopped = t.status === 0 || t.error;
        return {
            app: "io.github.anisthdev.Seedling",
            id: String(t.id),
            title: t.name,
            progress: t.percentDone,
            state: t.error ? "error" : states[t.status] ?? "downloading",
            error: t.error ? t.errorString || "Error" : "",
            detail: `${Math.floor(t.percentDone * 100)}% · ${size(t.sizeWhenDone - t.leftUntilDone)} of ${size(t.sizeWhenDone)} · ${state(t)}`,
            actions: [stopped ? "resume" : "pause"],
            open: ["seedling", "show", String(t.id)],
            added: t.addedDate * 1000
        };
    }

    // The dropdown's pause and resume
    function act(id, action) {
        if (action !== "pause" && action !== "resume")
            return;
        rpc(action === "pause" ? "torrent-stop" : "torrent-start", {
            ids: [id]
        }, () => refresh());
    }

    function size(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes, unit = 0;
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit++;
        }
        return unit === 0 ? `${value} B` : `${value.toFixed(value < 10 ? 1 : 0)} ${units[unit]}`;
    }

    function eta(seconds) {
        if (seconds < 0)
            return "";
        const minutes = Math.ceil(seconds / 60);
        if (minutes < 60)
            return `${minutes} min left`;
        const hours = Math.floor(minutes / 60);
        return minutes % 60 ? `${hours} h ${minutes % 60} min left` : `${hours} h left`;
    }

    // Speed and time left, or why it isn't moving
    function state(t) {
        if (t.error)
            return t.errorString || "Error";
        switch (t.status) {
        case 0:
            return "Paused";
        case 1:
        case 2:
            return "Verifying";
        case 3:
            return "Queued";
        }
        return [`${size(t.rateDownload)}/s`, eta(t.eta)].filter(s => s).join(" · ");
    }

    Timer {
        interval: root.expecting ? 500 : root.active.length > 0 || root.watching ? 1500 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Give up on an expected download that never turned up
    Timer {
        id: expectTimeout
        interval: 15000
        onTriggered: root.expecting = false
    }

    Timer {
        id: finishedTimer
        interval: 4000
        onTriggered: root.finished = null
    }
}
