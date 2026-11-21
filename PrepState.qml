pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Interview preparation, from `prep` (totoro-prep, on PATH): the phase and
// its exit test, problems to re-solve today, the attempt timer, the week so
// far. `prep status --json` is read whenever prep marks a change (it
// rewrites $XDG_DATA_HOME/prep/.changed in place), and on the minute for
// the date rolling over; changes go through `prep` too, so the files have
// one writer. Without prep installed, `available` stays false and the bar
// shows nothing. The pill (PrepPill), its dropdown (PrepCard) and the menu
// on Super+D (PrepMenu) show it.
Singleton {
    id: root

    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/prep"

    property bool available: false
    property var status: null
    // The problem list with how each went (prep problems --json), read
    // when the menu asks for it
    property var problems: []
    property var stories: null
    property double now: Date.now()

    readonly property var phase: status?.phase ?? null
    readonly property var due: status?.due ?? []
    readonly property var timer: status?.timer ?? null
    readonly property int timerMinutes: status?.timerMinutes ?? 35
    // Since the timer started, ms; it ticks only while there is one
    readonly property double elapsed: timer ? Math.max(0, now - new Date(timer.started).getTime()) : 0
    readonly property bool overTime: elapsed >= timerMinutes * 60000

    // "4:05", "1:02:03"
    function clock(ms) {
        const s = Math.floor(ms / 1000);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    function refresh() {
        statusProc.running = true;
    }

    function loadProblems() {
        problemsProc.running = true;
    }

    function loadStories() {
        storiesProc.running = true;
    }

    // Runs `prep ARGS…`; with `notify`, what it prints comes up as a
    // notification (errors always do). The stamp file brings the update.
    function run(args, notify) {
        Quickshell.execDetached(["sh", "-c", 'n=$1; shift; out=$(prep "$@" 2>&1); code=$?; if [ $code -ne 0 ] || [ "$n" = 1 ]; then notify-send -a Prep -i applications-development "Prep" "$out"; fi', "sh", notify ? "1" : "0", ...args.map(String)]);
    }

    function log(problem, result, extra) {
        run(["log", problem, result].concat(extra ?? []), true);
    }

    function startTimer(problem) {
        run(["timer", "start"].concat(problem ? [problem] : []), false);
    }

    function stopTimer() {
        run(["timer", "cancel"], false);
    }

    // The 35 minutes running out: said once per timer
    property string warnedFor: ""
    onOverTimeChanged: {
        if (!overTime || !timer || warnedFor === timer.started)
            return;
        warnedFor = timer.started;
        Quickshell.execDetached(["notify-send", "-a", "Prep", "-i", "alarm-timer", `${timerMinutes} minutes`, timer.title ? `${timer.title}: time to log it, or keep going and say so` : "Time's up"]);
    }

    Process {
        id: statusProc

        command: ["prep", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                    root.available = true;
                } catch (e) {}
                // The stamp exists now; watch it from here on
                if (!stamp.loaded)
                    stamp.reload();
            }
        }
        onExited: code => {
            if (code !== 0)
                root.available = false;
        }
    }

    Process {
        id: problemsProc

        command: ["prep", "problems", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.problems = JSON.parse(text).problems;
                } catch (e) {}
            }
        }
    }

    Process {
        id: storiesProc

        command: ["prep", "stories", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.stories = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    FileView {
        id: stamp

        property bool loaded: false

        path: root.dataDir + "/.changed"
        watchChanges: true
        printErrors: false
        onLoaded: loaded = true
        onFileChanged: {
            reload();
            root.refresh();
            if (root.problems.length)
                root.loadProblems();
        }
    }

    // The date rolling over (and a fallback for a change missed)
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // The timer's clock
    Timer {
        interval: 1000
        running: root.timer !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // `qs -c quickbar ipc call prepbar toggle`: the pill hidden for a day
    // off, or back (Super+Shift+D)
    IpcHandler {
        target: "prepbar"

        function toggle(): void {
            Settings.showPrep = !Settings.showPrep;
            Quickshell.execDetached(["notify-send", "-a", "Prep", "-i", "applications-development", "-h", "string:x-canonical-private-synchronous:prepbar", "Prep", Settings.showPrep ? "Back in the bar" : "Hidden. Enjoy the day off"]);
        }
    }

    Component.onCompleted: refresh()
}
