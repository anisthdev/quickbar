import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The entertainment menu: Library and Music library open the video and
// music libraries (Reel, MusicMenu); Play URL, the Jackett searches and
// Music (YouTube Music, through tunes) open quickbar's own search window;
// RetroArch NES its game list. Hindi films aren't listed: `ipc call search
// open hindi` opens that search.
Scope {
    id: root

    required property var search
    required property var games
    required property var reel
    required property var music

    LauncherWindow {
        id: launcher

        title: "Entertainment"
        entries: [
            {
                label: "Library",
                icon: "applications-multimedia",
                reel: true
            },
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
                label: "Music library",
                icon: "multimedia-audio-player",
                music: true
            },
            {
                label: "Music",
                icon: "appimagekit-youtube-music",
                search: "music"
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
        onActivated: entry => entry.reel ? root.reel.show() : entry.music ? root.music.show() : entry.games ? root.games.show() : root.search.show(entry.search)
    }

    // `qs -p <dir> ipc call entertainment toggle`, e.g. from Super+E
    IpcHandler {
        target: "entertainment"

        function toggle(): void {
            launcher.toggle();
        }
    }
}
