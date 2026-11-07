import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The entertainment menu: Movies/TV and Music open the video and
// music libraries' menus (ReelMenu, MusicMenu); Search opens quickbar's search window
// (Jackett's movies, anime, Hindi films and ebooks, and YouTube Music
// through tunes, chosen inside it) on its last mode, and Play URL the same
// window for a link; RetroArch NES its game list. Jellyfin switches the
// media server for the TV (the `jellyfin` user service) on or off: it's off
// unless wanted, as it's rarely used.
Scope {
    id: root

    required property var search
    required property var games
    required property var videos
    required property var music

    property bool jellyfinOn: false

    LauncherWindow {
        id: launcher

        title: "Entertainment"
        onOpenChanged: if (open)
            jellyfinCheck.running = true
        entries: [
            {
                label: "Movies/TV",
                icon: "applications-multimedia",
                keywords: "library video films shows",
                videos: true
            },
            {
                label: "Music",
                icon: "multimedia-audio-player",
                keywords: "library songs albums mpd",
                music: true
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
                label: "Search",
                icon: "preferences-desktop-search",
                subtitle: "Movies, anime, Hindi, music, ebooks",
                keywords: "movies tv anime hindi music ebooks books torrent jackett",
                search: ""
            },
            {
                label: "RetroArch NES",
                icon: "retroarch",
                games: true
            }
        ]
        onActivated: entry => entry.jellyfin ? root.toggleJellyfin() : entry.videos ? root.videos.show() : entry.music ? root.music.show() : entry.games ? root.games.show() : root.search.show(entry.search)
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
