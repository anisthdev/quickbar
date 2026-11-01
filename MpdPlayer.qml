pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// mpd, for everything in the shell that shows or drives it (the bar's now
// playing chip, the music menu): what's playing, where it is, the options,
// the queue and the song's art, and the commands. State comes from mpc:
// `mpc idleloop` says when something changed and a short query reads it;
// elapsed time ticks locally between.
Singleton {
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
    // mpd's queue: [{ file, title, artist, album, seconds }], and the
    // playing song's place in it (-1 when none)
    property var queue: []
    property int position: -1

    readonly property bool playing: state === "playing"
    readonly property bool active: state !== "stopped" && file !== ""

    function mpc(...args) {
        Quickshell.execDetached(["mpc", "-q", ...args]);
    }

    // "1:23" or "1:02:03" -> seconds
    function seconds(text) {
        return text.split(":").reduce((total, part) => total * 60 + (parseInt(part) || 0), 0);
    }

    // Plays `files` in place of the queue, from the one at `from` (0-based)
    function playFiles(files, from) {
        if (files.length === 0)
            return;
        Quickshell.execDetached(["sh", "-c", 'n=$1; shift; mpc -q clear && mpc -q add "$@" && mpc -q play "$n"', "sh", String(Math.max(0, from ?? 0) + 1), ...files]);
    }

    // mpd's playlist `name` in place of the queue, from its song at
    // `position` (1-based, as mpd counts its loaded songs)
    function playPlaylist(name, position) {
        Quickshell.execDetached(["sh", "-c", 'mpc -q clear && mpc -q load "$1" && mpc -q play "$2"', "sh", name, String(position ?? 1)]);
    }

    // After what's queued
    function enqueue(files) {
        if (files.length > 0)
            mpc("add", ...files);
    }

    // Right after the playing song (at the end, with none playing)
    function playNext(files) {
        if (files.length > 0)
            mpc("insert", ...files);
    }

    // The queue's song at `index` (0-based)
    function playAt(index) {
        mpc("play", String(index + 1));
    }

    // Queue edits, 0-based
    function moveInQueue(from, to) {
        mpc("move", String(from + 1), String(to + 1));
    }

    function removeFromQueue(index) {
        mpc("del", String(index + 1));
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

    // Replaced only when it changed: a new list resets what shows it
    function parseQueue(lines) {
        const next = lines.filter(l => l !== "").map(l => {
            const [path, tagTitle, tagArtist, tagAlbum, time] = l.split("@@");
            return {
                file: path,
                title: tagTitle || path.split("/").pop().replace(/\.[^.]+$/, ""),
                artist: tagArtist ?? "",
                album: tagAlbum ?? "",
                seconds: seconds(time ?? "0")
            };
        });
        if (JSON.stringify(next) !== JSON.stringify(queue))
            queue = next;
    }

    // Tells us when the player, queue or options change
    Process {
        id: idle

        // Ended with the shell, or killing it would leave the loop behind
        command: ["setpriv", "--pdeathsig", "TERM", "mpc", "idleloop", "player", "playlist", "options"]
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

    // The status and the song on their own lines (even when empty), then
    // the queue, a song a line
    Process {
        id: query

        running: true
        command: ["sh", "-c", "printf '%s\\n' \"$(mpc status '%state%@@%currenttime%@@%totaltime%@@%random%@@%repeat%@@%single%@@%songpos%')\" \"$(mpc current -f '%title%@@%artist%@@%album%@@%file%')\"; mpc playlist -f '%file%@@%title%@@%artist%@@%album%@@%time%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const s = (lines[0] ?? "").split("@@");
                root.state = s[0] || "stopped";
                root.elapsed = root.seconds(s[1] ?? "0");
                root.duration = root.seconds(s[2] ?? "0");
                root.random = s[3] === "on";
                root.repeat = s[4] === "on";
                root.single = s[5] === "on";
                root.position = root.state === "stopped" ? -1 : (parseInt(s[6]) || 0) - 1;
                root.parseCurrent((lines[1] ?? "").split("@@"));
                root.parseQueue(lines.slice(2));
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
}
