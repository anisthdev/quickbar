pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every download in one list, newest first, whoever does it: Transmission's
// torrents (the Transmission singleton) and the jobs of quickbar's runner
// (scripts/download: yt-dlp through tunes, or any script). Each is
//
//   { key, provider, title, subtitle, progress, state, detail, error,
//     canPause, canCancel, added }
//
// state is downloading, verifying, queued, paused, processing (filing it
// once downloaded) or error. A failed runner job stays until dismissed.
// The runner's jobs are read with `download list`: every 1.5 s while one
// downloads or someone is watching, every 10 s otherwise, and every half
// second for a moment after expect().
Singleton {
    id: root

    readonly property string runner: Quickshell.shellDir + "/scripts/download"

    property var active: []
    // key → download, for lists keyed by key so their rows stay put
    property var byKey: ({})
    // A download that just finished, kept for a moment: { title }
    property var finished: null
    // Something (the downloads card) wants live numbers
    property bool watching: false
    // A runner job was just started and hasn't shown up yet
    property bool expecting: false
    property double expectedSince: 0

    property var torrents: []
    property var jobs: []

    // A download is on its way. Transmission's, or else the runner's.
    function expect(provider) {
        if (provider === "transmission") {
            Transmission.expect();
            return;
        }
        expectedSince = Date.now();
        expecting = true;
        expectTimeout.restart();
        list.running = true;
    }

    function toggle(d) {
        if (d.provider === "transmission")
            Transmission.toggle(d.source);
        else if (d.canPause)
            run(d.state === "paused" || d.state === "error" ? "resume" : "pause", d);
    }

    // Stop and remove a runner job, or clear away a failed one
    function cancel(d) {
        if (d.canCancel)
            run(d.state === "error" ? "dismiss" : "cancel", d);
    }

    function run(action, d) {
        Quickshell.execDetached([runner, action, d.source.id]);
        soon.restart();
    }

    function fromTorrent(t) {
        const states = ["paused", "verifying", "verifying", "queued", "downloading", "queued", "downloading"];
        const have = Transmission.size(t.sizeWhenDone - t.leftUntilDone);
        return {
            key: `tr:${t.id}`,
            provider: "transmission",
            title: t.name,
            subtitle: "",
            progress: t.percentDone,
            state: t.error ? "error" : states[t.status] ?? "downloading",
            error: t.error ? t.errorString || "Error" : "",
            detail: `${Math.floor(t.percentDone * 100)}% · ${have} of ${Transmission.size(t.sizeWhenDone)} · ${Transmission.state(t)}`,
            canPause: true,
            canCancel: false,
            added: t.addedDate * 1000,
            source: t
        };
    }

    function fromJob(j) {
        const progress = j.progress ?? 0;
        const item = j.item?.total > 1 ? `${Math.max(1, j.item.index)} of ${j.item.total}` : "";
        let parts;
        switch (j.state) {
        case "error":
            parts = [j.error || "Failed"];
            break;
        case "processing":
            parts = [j.status || "Processing"];
            break;
        case "queued":
            parts = ["Queued"];
            break;
        case "paused":
            parts = [`${Math.floor(progress * 100)}%`, item, "Paused"];
            break;
        default:
            parts = [`${Math.floor(progress * 100)}%`, item, j.rate ? `${Transmission.size(j.rate)}/s` : "", j.eta > 0 ? Transmission.eta(j.eta) : ""];
        }
        return {
            key: `dl:${j.id}`,
            provider: "runner",
            title: j.title,
            subtitle: j.subtitle ?? "",
            progress: progress,
            state: j.state,
            error: j.state === "error" ? j.error || "Failed" : "",
            detail: [j.subtitle, ...parts].filter(s => s).join(" · "),
            canPause: j.state !== "processing",
            canCancel: true,
            added: (j.added ?? 0) * 1000,
            source: j
        };
    }

    function merge() {
        const all = torrents.map(fromTorrent).concat(jobs.filter(j => j.state !== "done").map(fromJob)).sort((a, b) => b.added - a.added);
        const map = {};
        for (const d of all)
            map[d.key] = d;
        byKey = map;
        active = all;
    }

    function readJobs(text) {
        let next;
        try {
            next = JSON.parse(text);
        } catch (e) {
            return;
        }
        // A job that was going and is now done: it finished
        const done = next.find(j => j.state === "done" && jobs.some(p => p.id === j.id && p.state !== "done"));
        if (done)
            finish(done.title);
        if (expecting && next.some(j => j.added * 1000 >= expectedSince - 5000))
            expecting = false;
        jobs = next;
        merge();
    }

    function finish(title) {
        finished = {
            title: title
        };
        finishedTimer.restart();
    }

    Binding {
        target: Transmission
        property: "watching"
        value: root.watching
    }

    Connections {
        target: Transmission

        function onActiveChanged() {
            root.torrents = Transmission.active;
            root.merge();
        }

        function onFinishedChanged() {
            if (Transmission.finished)
                root.finish(Transmission.finished.name);
        }
    }

    Process {
        id: list

        command: [root.runner, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.readJobs(text)
        }
    }

    Timer {
        interval: root.expecting ? 500 : root.jobs.some(j => j.state !== "done" && j.state !== "error") || root.watching ? 1500 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: list.running = true
    }

    // Read again just after a pause, resume or cancel
    Timer {
        id: soon

        interval: 300
        onTriggered: list.running = true
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
