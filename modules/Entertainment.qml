import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The entertainment menu: Play URL and the Jackett searches open quickbar's
// own search window, RetroArch NES its game list. Hindi
// films aren't listed: `ipc call search open hindi` opens that search.
Scope {
    id: root

    required property var search
    required property var games

    LauncherWindow {
        id: launcher

        title: "Entertainment"
        entries: [
            {
                label: "Play URL",
                icon: "mpv",
                search: "play"
            },
            {
                label: "Movies/TV",
                icon: "com.github.rafostar.Clapper",
                search: "movies"
            },
            {
                label: "Anime",
                icon: "crunchyroll",
                search: "anime"
            },
            {
                label: "Ebooks",
                icon: "accessories-ebook-reader",
                search: "books"
            },
            {
                label: "RetroArch NES",
                icon: "retroarch",
                games: true
            }
        ]
        onActivated: entry => entry.games ? root.games.show() : root.search.show(entry.search)
    }

    // `qs -p <dir> ipc call entertainment toggle`, e.g. from Super+E
    IpcHandler {
        target: "entertainment"

        function toggle(): void {
            launcher.toggle();
        }
    }
}
