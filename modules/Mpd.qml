import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// mpd's now playing chip: album art, the title and a little equalizer while
// it plays; hidden when stopped. Click for the media card, middle-click to
// play/pause. State comes from mpc: `mpc idleloop` says when something
// changed and a short query reads it; elapsed time ticks locally between.
Pill {
    id: root

    readonly property string artDir: Quickshell.env("HOME") + "/.cache/quickbar/mpd-art"

    property string state: "stopped"
    property string title
    property string artist
    property string album
    property string file
    property real elapsed: 0
    property real duration: 0
    property bool random: false
    property bool repeat: false
    property bool single: false
    property string art: ""

    readonly property bool playing: state === "playing"

    function mpc(...args) {
        Quickshell.execDetached(["mpc", "-q", ...args]);
    }

    // "1:23" or "1:02:03" -> seconds
    function seconds(text) {
        return text.split(":").reduce((total, part) => total * 60 + (parseInt(part) || 0), 0);
    }

    // Many files carry their tags only in the name: "Artist - Title.mp3"
    function parseCurrent(fields) {
        const [tagTitle, tagArtist, tagAlbum, path] = fields;
        const name = (path ?? "").split("/").pop().replace(/\.[^.]+$/, "");
        const dash = name.indexOf(" - ");
        title = tagTitle || (dash > 0 ? name.slice(dash + 3) : name);
        artist = tagArtist || (dash > 0 ? name.slice(0, dash) : "");
        album = tagAlbum ?? "";
        if (path !== file) {
            file = path ?? "";
            art = "";
            if (file)
                artProc.running = true;
        }
    }

    padding: 8
    spacing: 8
    visible: state !== "stopped" && file !== ""
    clickable: true
    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            mpc("toggle");
        else
            card.toggle();
    }

    // Tells us when the player, queue or options change
    Process {
        id: idle

        command: ["mpc", "idleloop", "player", "playlist", "options"]
        running: true
        stdout: SplitParser {
            onRead: query.running = true
        }
        // mpd restarting ends the loop; pick it back up
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: {
            idle.running = true;
            query.running = true;
        }
    }

    Process {
        id: query

        running: true
        command: ["sh", "-c", "mpc status '%state%@@%currenttime%@@%totaltime%@@%random%@@%repeat%@@%single%'; mpc current -f '%title%@@%artist%@@%album%@@%file%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [status, current] = text.split("\n");
                const s = (status ?? "").split("@@");
                root.state = s[0] || "stopped";
                root.elapsed = root.seconds(s[1] ?? "0");
                root.duration = root.seconds(s[2] ?? "0");
                root.random = s[3] === "on";
                root.repeat = s[4] === "on";
                root.single = s[5] === "on";
                root.parseCurrent((current ?? "").split("@@"));
            }
        }
    }

    // Embedded art, extracted once per song into a cache
    Process {
        id: artProc

        command: ["sh", "-c", 'mkdir -p "$1" && out="$1/$2"; [ -s "$out" ] || { mpc readpicture "$3" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"; }; if [ -s "$out" ]; then echo "$out"; else rm -f "$out"; fi', "sh", root.artDir, Qt.md5(root.file), root.file]
        stdout: StdioCollector {
            onStreamFinished: root.art = text.trim() ? `file://${text.trim()}` : ""
        }
    }

    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.elapsed = Math.min(root.duration, root.elapsed + 1)
    }

    AlbumArt {
        anchors.verticalCenter: parent.verticalCenter
        size: 20
        source: root.art
    }

    Label {
        width: Math.min(implicitWidth, 180)
        text: root.title
        elide: Text.ElideRight
        opacity: root.playing ? 1 : 0.6

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animNormal
            }
        }
    }

    Equalizer {
        playing: root.playing
        color: Theme.primary
    }

    MediaCard {
        id: card
        owner: root
        player: root
    }

    // `qs -p <dir> ipc call media toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "media"

        function toggle(): void {
            card.toggle();
        }
    }
}
