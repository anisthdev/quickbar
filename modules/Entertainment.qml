import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The entertainment menu: the Jackett searches open quickbar's own search
// window; Play URL and RetroArch still run their rofi menus for now. Hindi
// films aren't listed: `ipc call search open hindi` opens that search.
Scope {
    id: root

    required property var search

    readonly property string menus: Quickshell.env("HOME") + "/.local/bin/menus"

    LauncherWindow {
        id: launcher

        title: "Entertainment"
        entries: [
            {
                label: "Play URL",
                icon: "mpv",
                script: "play-video"
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
                script: "retroarch-nes"
            }
        ]
        onActivated: entry => {
            if (entry.search)
                root.search.show(entry.search);
            else
                Quickshell.execDetached([`${root.menus}/${entry.script}`]);
        }
    }

    // `qs -p <dir> ipc call entertainment toggle`, e.g. from Super+E
    IpcHandler {
        target: "entertainment"

        function toggle(): void {
            launcher.toggle();
        }
    }
}
