import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The video library's data and playback, for the menu (ReelMenu): reel
// (reel-scan, on PATH) keeps ~/.cache/reel/library.json (titles, episodes,
// TMDB details and pictures), mpv keeps the progress (its watch_later files
// and watch history, read by scripts/watch-progress), and this joins them
// into `model` (every title with how far it's been watched, and what's next
// in a series) and `rows` (Continue watching, then reel's rows, recently
// played first). mpv plays: a movie resumes where it stopped; a series plays
// from the picked episode on, the rest queued.
//
// It used to be a full-screen app of its own too; the menu replaced it.
Scope {
    id: root

    readonly property string cache: Quickshell.env("HOME") + "/.cache/reel"

    property var library: null
    property var progress: ({
            resume: {},
            played: {},
            marks: {},
            tracks: {}
        })

    // library.json with progress worked in, and the rows to show
    readonly property var model: build(library, progress)
    readonly property var rows: model.rows

    // Progress read again, and reel rescans; library.json changes only
    // when something did. The menu calls it as it opens
    function load() {
        refresh();
        scan.running = true;
    }

    function refresh() {
        progressRead.running = true;
    }

    // Close enough to the end to count as watched: credits, an anime ED,
    // a stop just before the end
    function finished(position, duration) {
        return duration > 0 && duration - position <= Math.max(90, duration * 0.05);
    }

    function build(lib, prog) {
        if (!lib)
            return {
                items: [],
                rows: []
            };
        const marks = prog.marks ?? {};
        // A file's state: mpv's (played to the end, mpv drops the resume
        // file, so played with none left means watched), unless it was
        // marked by hand since it last played
        const fileState = (file, duration) => {
            const resume = prog.resume[file.watch_later];
            const played = Math.max(prog.played[file.path] ?? 0, resume ? resume[1] : 0);
            const mark = marks[file.path];
            if (mark && mark[1] >= played)
                return {
                    lastPlayed: mark[1],
                    watched: mark[0],
                    position: 0,
                    progress: 0
                };
            const watched = resume ? finished(resume[0], duration) : played > 0;
            const position = resume && !watched ? resume[0] : 0;
            return {
                lastPlayed: played,
                watched,
                position,
                progress: duration ? position / duration : 0
            };
        };
        const items = lib.items.map(src => {
            const item = Object.assign({}, src);
            item.tracks = prog.tracks?.[item.id] ?? null;
            if (item.kind === "movie")
                return Object.assign(item, fileState(item, item.duration));
            item.lastPlayed = 0;
            let latest = -1;
            item.episodes = src.episodes.map((e, i) => {
                const ep = Object.assign({}, e, fileState(e, e.duration));
                if (ep.lastPlayed > item.lastPlayed) {
                    item.lastPlayed = ep.lastPlayed;
                    latest = i;
                }
                return ep;
            });
            // Next: from the one last played (or marked) on, the first not
            // seen to the end, so one stopped halfway carries on
            item.next = latest < 0 ? -1 : item.episodes.findIndex((e, i) => i >= latest && !e.watched);
            item.started = item.episodes.some(e => e.watched || e.position > 0);
            const next = item.episodes[item.next];
            item.progress = next ? next.progress : 0;
            return item;
        });
        const byRecent = (a, b) => b.lastPlayed - a.lastPlayed || a.title.localeCompare(b.title);
        const rows = [];
        const going = items.filter(i => i.lastPlayed > 0 && (i.kind === "movie" ? i.position > 0 : i.next >= 0 && i.started)).sort(byRecent);
        if (going.length > 0)
            rows.push({
                name: "Continue watching",
                wide: true,
                items: going
            });
        for (const name of lib.rows) {
            const inRow = items.filter(i => i.category === name).sort(byRecent);
            if (inRow.length > 0)
                rows.push({
                    name,
                    wide: false,
                    items: inRow
                });
        }
        return {
            items,
            rows
        };
    }

    // A movie resumes by itself (mpv's watch_later); a series queues every
    // episode, from the picked one on, so next and previous move between
    // them. fromStart plays the picked file from its beginning. The title's
    // languages (picked in the menu) beat what mpv saved for the file.
    function play(item, index, fromStart) {
        const files = item.kind === "movie" ? [item] : item.episodes;
        const at = item.kind === "movie" ? 0 : index;
        const args = ["uwsm", "app", "--", "mpv", "--player-operation-mode=pseudo-gui", `--playlist-start=${at}`];
        const tracks = item.tracks;
        if (tracks?.audio)
            args.push("--aid=auto", `--alang=${tracks.audio}`);
        if (tracks?.subs === "no")
            args.push("--sid=no");
        else if (tracks?.subs)
            args.push("--sid=auto", `--slang=${tracks.subs}`);
        // Paths are absolute, so none passes for an option; the picked one
        // starts over in a group of its own (per-file options)
        files.forEach((f, i) => {
            if (fromStart && i === at)
                args.push("--{", "--start=0", f.path, "--}");
            else
                args.push(f.path);
        });
        player.createObject(root, {
            command: args
        });
    }

    // Seen or not, by hand: files from the library's items or episodes
    function mark(files, watched) {
        if (files.length === 0)
            return;
        writer.createObject(root, {
            command: [Quickshell.shellDir + "/scripts/watch-progress", "mark", watched ? "watched" : "unwatched"].concat(files.map(f => f.path))
        });
    }

    // The languages to play a title in: a code, "" for mpv's choice, or
    // subs "no"
    function setTracks(item, audio, subs) {
        writer.createObject(root, {
            command: [Quickshell.shellDir + "/scripts/watch-progress", "tracks", item.id, audio, subs]
        });
    }

    function runtime(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    function left(item) {
        return `${runtime(item.duration - item.position)} left`;
    }

    function code(ep) {
        return `S${String(ep.season).padStart(2, "0")}E${String(ep.episode).padStart(2, "0")}`;
    }

    FileView {
        path: root.cache + "/library.json"
        watchChanges: true
        printErrors: false
        blockLoading: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.library = JSON.parse(text());
            } catch (e) {}
        }
    }

    Process {
        id: progressRead

        command: [Quickshell.shellDir + "/scripts/watch-progress"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.progress = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: scan

        command: ["reel-scan"]
    }

    // One per change to the marks or languages; the progress read again after
    Component {
        id: writer

        Process {
            running: true
            onExited: {
                root.refresh();
                destroy();
            }
        }
    }

    // One per playback; when mpv closes, the progress is read again
    Component {
        id: player

        Process {
            running: true
            onExited: {
                root.refresh();
                destroy();
            }
        }
    }
}
