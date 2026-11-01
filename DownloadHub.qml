pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every download in one list, newest first, whoever does it; the bar's
// downloads pill and dropdown show it. docs/downloads.md is the contract:
// apps send their downloads over a socket (one JSON object a line, both
// ways), scripts through scripts/download (the same socket), daemons are
// read by providers here (Transmission), and progress notifications are
// bridged in (Notifications). Each download is
//
//   { app, id, title, subtitle, progress, state, detail, error, actions,
//     open, icon, appName, key, added }
//
// state is queued, downloading, verifying, paused, processing or error;
// progress null while it can't tell. A finished one is gone at once,
// kept in `finished` for the pill to show a moment.
Singleton {
    id: root

    readonly property string socketDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickbar"
    readonly property string socketPath: socketDir + "/downloads.sock"

    // Newest first
    property var active: []
    // key → download, for lists keyed by key so their rows stay put
    property var byKey: ({})
    // A download that just finished, kept for a moment: { title }
    property var finished: null
    // Something (the downloads dropdown) wants live numbers
    property bool watching: false

    // key → { download, owner, updated }. owner is the Socket that sent it,
    // "detached" (one message at a time, dropped when it goes quiet), a
    // provider's name, or "notification"
    property var entries: ({})
    // Detached downloads not heard from in this long are dropped
    readonly property int detachedTimeout: 60000

    function keyOf(app, id) {
        return `${app}/${id}`;
    }

    // Adds a download or merges fields into it
    function put(fields, owner) {
        const key = keyOf(fields.app, fields.id);
        const old = entries[key];
        const download = Object.assign({
            title: "",
            subtitle: "",
            progress: null,
            state: "downloading",
            detail: "",
            error: "",
            actions: [],
            added: Date.now()
        }, old?.download ?? {}, fields, {
            key: key
        });
        if (download.state !== "error")
            download.error = "";
        entries[key] = {
            download: download,
            owner: owner,
            updated: Date.now()
        };
    }

    function finish(key) {
        const entry = entries[key];
        if (!entry)
            return;
        delete entries[key];
        finished = {
            title: entry.download.title
        };
        finishedTimer.restart();
    }

    function fail(key, error) {
        const entry = entries[key];
        if (!entry)
            return;
        entry.download = Object.assign({}, entry.download, {
            state: "error",
            error: error || "Failed",
            progress: entry.download.progress ?? 0
        });
    }

    // Puts a provider's downloads in place of the ones it had
    function provide(owner, downloads) {
        for (const key of Object.keys(entries))
            if (entries[key].owner === owner && !downloads.some(d => keyOf(d.app, d.id) === key))
                delete entries[key];
        for (const d of downloads)
            put(d, owner);
        rebuild();
    }

    function rebuild() {
        const all = Object.values(entries).map(e => e.download).sort((a, b) => b.added - a.added);
        const map = {};
        for (const d of all)
            map[d.key] = d;
        byKey = map;
        active = all;
    }

    // A line from an app (or scripts/download), see docs/downloads.md
    function receive(socket, line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.op === "poke") {
            poke(m.provider);
            return;
        }
        if (!m.app || m.id === undefined || m.id === null)
            return;
        m.id = String(m.id);
        const key = keyOf(m.app, m.id);
        const owner = m.detached ? "detached" : socket;
        const fields = Object.assign({}, m);
        delete fields.op;
        delete fields.detached;
        switch (m.op) {
        case "update":
            put(fields, owner);
            break;
        case "done":
            finish(key);
            break;
        case "fail":
            put(fields, owner);
            fail(key, m.error);
            break;
        case "remove":
            delete entries[key];
            break;
        default:
            return;
        }
        rebuild();
    }

    // An app went away: what it was still downloading stopped
    function disconnected(socket) {
        let changed = false;
        for (const key of Object.keys(entries)) {
            const entry = entries[key];
            if (entry.owner !== socket)
                continue;
            entry.owner = null;
            entry.download = Object.assign({}, entry.download, {
                state: "error",
                error: entry.download.state === "error" ? entry.download.error : "Stopped unexpectedly",
                actions: ["dismiss"]
            });
            changed = true;
        }
        if (changed)
            rebuild();
    }

    // A button in the dropdown: the owner does it, and says what came of it
    function act(download, action) {
        const entry = entries[download.key];
        if (!entry)
            return;
        const owner = entry.owner;
        if (owner === "transmission") {
            Transmission.act(Number(download.id), action);
        } else if (owner === "notification") {
            notifications[download.id]?.dismiss();
        } else if (owner && typeof owner === "object" && owner.connected) {
            owner.write(JSON.stringify({
                op: "action",
                app: download.app,
                id: download.id,
                action: action
            }) + "\n");
            owner.flush();
        } else if (action === "dismiss" || action === "cancel") {
            // Nobody to ask any more
            delete entries[download.key];
            rebuild();
        }
    }

    // A click on its row: its own command, else the shell's window for its
    // app (shellWindows), else its app
    function open(download) {
        if (download.open?.length > 0) {
            const home = Quickshell.env("HOME");
            Quickshell.execDetached(download.open.map(a => String(a).replace(/^~(?=\/|$)/, home)));
            return;
        }
        const own = shellWindows[download.app];
        if (own) {
            own();
            return;
        }
        DesktopEntries.byId(download.app)?.execute();
    }

    // Apps without a desktop entry of their own whose downloads one of the
    // shell's windows shows: tunes' music, in the music library
    readonly property var shellWindows: ({
            "tunes": () => {
                if (Panels.musicMenu && !Panels.musicMenu.open)
                    Panels.musicMenu.show();
            }
        })

    // The badge: the download's own icon, else its app's
    function iconOf(download) {
        if (!download.app)
            return "";
        const name = download.icon || DesktopEntries.byId(download.app)?.icon || "";
        if (name === "")
            return "";
        return name.startsWith("/") ? `file://${name}` : Quickshell.iconPath(name, true);
    }

    function appNameOf(download) {
        if (!download.app)
            return "";
        return download.appName || DesktopEntries.byId(download.app)?.name || download.app;
    }

    // Progress notifications (a "value" hint, 0–100), from Notifications:
    // downloads instead of popups, gone when the notification closes.
    // notification id → Notification
    property var notifications: ({})

    // A progress notification replaced by a plain message (a final "Done"):
    // out of the pill, for Notifications to show as a card
    signal becameMessage(var n)

    function notificationApp(n) {
        return n.desktopEntry || n.appName || "notification";
    }

    // A replacement (same id) may come as a new object: the latest is read
    function addNotification(n) {
        const id = String(n.id);
        const known = notifications[id];
        notifications[id] = n;
        if (known !== n) {
            const update = () => {
                if (notifications[id] !== n)
                    return;
                if (isNaN(Number(n.hints.value))) {
                    releaseNotification(id);
                    becameMessage(n);
                } else
                    showNotification(n);
            };
            n.hintsChanged.connect(update);
            n.summaryChanged.connect(update);
            n.bodyChanged.connect(update);
            n.closed.connect(() => {
                if (notifications[id] === n)
                    releaseNotification(id);
            });
        }
        showNotification(n);
    }

    // No longer a download: at 100% it finished, else it was dropped
    function releaseNotification(nid) {
        const id = String(nid);
        const n = notifications[id];
        if (!n)
            return;
        delete notifications[id];
        const key = keyOf(notificationApp(n), id);
        if (entries[key]?.download.progress >= 1)
            finish(key);
        else
            delete entries[key];
        rebuild();
    }

    function showNotification(n) {
        put({
            app: notificationApp(n),
            id: String(n.id),
            title: n.summary,
            detail: n.body.replace(/<[^>]*>/g, ""),
            progress: Math.max(0, Math.min(1, Number(n.hints.value) / 100)),
            state: "downloading",
            actions: ["dismiss"],
            icon: n.appIcon,
            appName: n.appName
        }, "notification");
        rebuild();
    }

    // Look for new downloads now, e.g. after adding a torrent
    function poke(provider) {
        if (provider === "transmission")
            Transmission.expect();
    }

    Binding {
        target: Transmission
        property: "watching"
        value: root.watching
    }

    // Transmission's unfinished torrents, as Seedling's downloads
    Connections {
        target: Transmission

        function onActiveChanged() {
            root.provide("transmission", Transmission.active.map(t => Transmission.toDownload(t)));
        }

        function onFinishedChanged() {
            if (Transmission.finished) {
                root.finished = {
                    title: Transmission.finished.name
                };
                finishedTimer.restart();
            }
        }
    }

    // The socket lives in a folder of quickbar's own
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.socketDir]
        onExited: server.active = true
    }

    SocketServer {
        id: server

        path: root.socketPath
        handler: Socket {
            id: client

            parser: SplitParser {
                onRead: line => root.receive(client, line)
            }
            onConnectionStateChanged: if (!connected)
                root.disconnected(client)
        }
    }

    // Detached downloads that went quiet
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            let changed = false;
            for (const key of Object.keys(root.entries)) {
                const entry = root.entries[key];
                if (entry.owner === "detached" && now - entry.updated > root.detachedTimeout) {
                    delete root.entries[key];
                    changed = true;
                }
            }
            if (changed)
                root.rebuild();
        }
    }

    Timer {
        id: finishedTimer

        interval: 4000
        onTriggered: root.finished = null
    }
}
