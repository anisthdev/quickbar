import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The app launcher, where rofi's drun opens: every app with its icon, the
// most launched first. It opens typing (see LauncherWindow for the keys),
// and matches names first, then descriptions and keywords.
//
// Launch counts are rofi's own (~/.cache/rofi3.druncache, which the rofi
// setup keeps adding to) plus quickbar's, kept in
// ~/.local/state/quickbar/launches.json.
Scope {
    id: root

    // desktop id → launches, from rofi
    property var rofiCounts: ({})

    function count(id) {
        return (rofiCounts[id] ?? 0) + (launches.counts[id] ?? 0);
    }

    function show() {
        rofiHistory.reload();
        launcher.show();
    }

    function toggle() {
        launcher.open ? launcher.hide() : show();
    }

    function launch(entry) {
        const counts = Object.assign({}, launches.counts);
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
        launches.counts = counts;
        entry.app.execute();
    }

    FileView {
        id: rofiHistory

        path: Quickshell.env("HOME") + "/.cache/rofi3.druncache"
        printErrors: false
        // "count id.desktop" a line
        onLoaded: {
            const counts = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\d+) (.+)\.desktop$/);
                if (m)
                    counts[m[2]] = Number(m[1]);
            }
            root.rofiCounts = counts;
        }
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickbar/launches.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: launches

            property var counts: ({})
        }
    }

    LauncherWindow {
        id: launcher

        placeholder: "Search your apps…"
        panelWidth: 440
        maxRows: 6
        startTyping: true
        entries: DesktopEntries.applications.values.filter(a => !a.noDisplay).map(a => ({
                    id: a.id.replace(/\.desktop$/, ""),
                    label: a.name,
                    icon: a.icon,
                    keywords: [a.genericName, a.comment, ...(a.keywords ?? [])].join(" "),
                    app: a
                })).sort((a, b) => root.count(b.id) - root.count(a.id) || a.label.localeCompare(b.label))
        onActivated: entry => root.launch(entry)
    }

    // `qs -p <dir> ipc call launcher toggle`, e.g. from Super+Space
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }
}
