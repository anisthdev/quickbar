import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The app launcher, where rofi's drun opens: every app with its icon, the
// most launched first. Keys as in the other menus (see LauncherWindow); the
// filter matches names first, then descriptions and keywords.
//
// Launch counts are quickbar's own, kept in
// ~/.local/state/quickbar/launches.json (rofi's were folded in once).
Scope {
    id: root

    function count(id) {
        return launches.counts[id] ?? 0;
    }

    function show() {
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
        entries: DesktopEntries.applications.values.filter(a => !a.noDisplay).map(a => ({
                    id: a.id.replace(/\.desktop$/, ""),
                    label: a.name,
                    icon: a.icon,
                    keywords: [a.genericName, a.comment, ...(a.keywords ?? [])].join(" "),
                    app: a
                })).sort((a, b) => root.count(b.id) - root.count(a.id) || a.label.localeCompare(b.label))
        onActivated: entry => root.launch(entry)
    }

    // `qs -c quickbar ipc call launcher toggle`, e.g. from Super+Space
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }
}
