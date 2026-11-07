import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The entertainment menu: Library and Music library open the video and
// music libraries (Reel, MusicMenu); Play URL, the Jackett searches and
// Music (YouTube Music, through tunes) open quickbar's own search window;
// RetroArch NES its game list. Jellyfin switches the media server for the
// TV (the `jellyfin` user service) on or off: it's off unless wanted, as
// it's rarely used. Hindi films aren't listed: `ipc call search open hindi`
// opens that search.
Scope {
    id: root

    required property var search
    required property var games
    required property var reel
    required property var music

    property bool jellyfinOn: false

    LauncherWindow {
        id: launcher

        title: "Entertainment"
        onOpenChanged: if (open)
            jellyfinCheck.running = true
        entries: [
            {
                label: "Library",
                icon: "applications-multimedia",
                reel: true
            },
            {
                label: "Jellyfin",
                icon: "org.jellyfin.JellyfinServer",
                subtitle: root.jellyfinOn ? "Serving the library to the TV" : "Media server for the TV",
                trailing: root.jellyfinOn ? "On" : "Off",
                keywords: "server tv",
                jellyfin: true
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
        onActivated: entry => entry.jellyfin ? root.toggleJellyfin() : entry.reel ? root.reel.show() : entry.music ? root.music.show() : entry.games ? root.games.show() : root.search.show(entry.search)
    }

    function toggleJellyfin() {
        jellyfinSwitch.starting = !jellyfinOn;
        jellyfinSwitch.command = ["systemctl", "--user", jellyfinSwitch.starting ? "start" : "stop", "jellyfin"];
        jellyfinSwitch.running = true;
    }

    Process {
        id: jellyfinCheck

        command: ["systemctl", "--user", "is-active", "--quiet", "jellyfin"]
        onExited: code => root.jellyfinOn = code === 0
    }

    Process {
        id: jellyfinSwitch

        property bool starting: false

        onExited: code => {
            jellyfinCheck.running = true;
            const body = code !== 0 ? "Couldn't " + (starting ? "start" : "stop") + " the server" : starting ? "On: the TV can connect" : "Off";
            Quickshell.execDetached(["notify-send", "-i", "org.jellyfin.JellyfinServer", "-h", "string:x-canonical-private-synchronous:jellyfin", "Jellyfin", body]);
        }
    }

    // `qs -c quickbar ipc call entertainment toggle`, e.g. from Super+E
    IpcHandler {
        target: "entertainment"

        function toggle(): void {
            launcher.toggle();
        }
    }
}
