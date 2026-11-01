pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// One timer for the shell: a countdown, or pomodoro's focus and breaks.
// The clock pill shows it while it runs (modules/Clock.qml) and the
// calendar menu has its controls. Kept in ~/.cache/quickbar/
// timer.json, so it carries on across a reload of the shell. When it's up
// it chimes and notifies with what's next: again or five more minutes for
// a countdown, the break after focus (a long one every fourth), focus after
// a break.
Singleton {
    id: root

    readonly property int focusMinutes: 30
    readonly property int breakMinutes: 5
    readonly property int longBreakMinutes: 15
    readonly property string sound: Quickshell.env("HOME") + "/.local/share/sounds/macos/complete.ogg"

    // "" (none), "timer", "focus" or "break"
    property string kind
    // Its whole length, ms
    property double total: 0
    // When it's up (epoch ms) while running; 0 while paused
    property double endsAt: 0
    // What was left when paused, ms
    property double left: 0
    // Focus sessions finished in a row, for the long break
    property int rounds: 0
    property double now: Date.now()

    readonly property bool active: kind !== ""
    readonly property bool paused: active && endsAt === 0
    readonly property double remaining: !active ? 0 : paused ? left : Math.max(0, endsAt - now)
    // What's left of it, 1 to 0
    readonly property real progress: total > 0 ? remaining / total : 0
    readonly property string label: kind === "focus" ? "Focus" : kind === "break" ? "Break" : "Timer"

    // "4:05", "1:02:03"
    function clock(ms) {
        const s = Math.ceil(ms / 1000);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    function start(minutes, what) {
        kind = what || "timer";
        total = minutes * 60000;
        endsAt = Date.now() + total;
        left = 0;
        now = Date.now();
        save();
    }

    // Pomodoro: focus, then the break that's due
    function focus() {
        start(focusMinutes, "focus");
    }

    function takeBreak() {
        start(rounds > 0 && rounds % 4 === 0 ? longBreakMinutes : breakMinutes, "break");
    }

    function pause() {
        if (!active || paused)
            return;
        left = Math.max(0, endsAt - Date.now());
        endsAt = 0;
        save();
    }

    function resume() {
        if (!paused)
            return;
        endsAt = Date.now() + left;
        now = Date.now();
        save();
    }

    function toggle() {
        paused ? resume() : pause();
    }

    // More time, running or paused
    function add(minutes) {
        if (!active)
            return;
        total += minutes * 60000;
        if (paused)
            left += minutes * 60000;
        else
            endsAt += minutes * 60000;
        save();
    }

    // Pomodoro's run of focus sessions ends too, unless it's only this
    // one that's up
    function stop(keepRounds) {
        kind = "";
        total = endsAt = left = 0;
        if (!keepRounds)
            rounds = 0;
        save();
    }

    function save() {
        store.setText(JSON.stringify({
            kind,
            total,
            endsAt,
            left,
            rounds
        }));
    }

    // It's up: a chime, and the notification with what's next
    function finish() {
        const was = kind;
        const minutes = Math.round(total / 60000);
        if (was === "focus")
            rounds++;
        stop(true);
        Quickshell.execDetached(["pw-play", sound]);
        let args;
        if (was === "focus") {
            const long = rounds % 4 === 0;
            args = ["-A", "default=Start break", "-A", "stop=Done for now", "Focus done", `Time for a ${long ? "long " : ""}break (${long ? longBreakMinutes : breakMinutes} min) · ${rounds} in a row`];
        } else if (was === "break") {
            args = ["-A", "default=Start focus", "-A", "stop=Done for now", "Break over", `Back to it: ${focusMinutes} min of focus`];
        } else {
            args = ["-A", "again=Again", "-A", "more=+5 min", "Time's up", `${minutes} min timer`];
        }
        notice.was = was;
        notice.minutes = minutes;
        // Normal, not critical, so it goes by itself; long enough to pick
        // what's next
        notice.command = ["notify-send", "-a", "Timer", "-i", "alarm-symbolic", "-t", "20000", ...args];
        notice.running = true;
    }

    FileView {
        id: store

        path: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/quickbar/timer.json`
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.kind = s.kind ?? "";
                root.total = s.total ?? 0;
                root.endsAt = s.endsAt ?? 0;
                root.left = s.left ?? 0;
                root.rounds = s.rounds ?? 0;
                root.now = Date.now();
            } catch (e) {}
        }
    }

    // The pick on the notification
    Process {
        id: notice

        property string was
        property int minutes

        stdout: StdioCollector {
            onStreamFinished: {
                const pick = text.trim();
                if (notice.was === "focus" && pick === "default")
                    root.takeBreak();
                else if (notice.was === "break" && pick === "default")
                    root.focus();
                else if (pick === "again")
                    root.start(notice.minutes);
                else if (pick === "more")
                    root.start(5);
                else if (pick === "stop")
                    root.rounds = 0;
            }
        }
    }

    Timer {
        interval: 250
        running: root.active && !root.paused
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.remaining <= 0)
                root.finish();
        }
    }

    // `qs -c quickbar ipc call timer start 10` (minutes), or focus, pause,
    // resume, toggle, add 5, stop
    IpcHandler {
        target: "timer"

        function start(minutes: int): void {
            root.start(minutes);
        }

        function focus(): void {
            root.focus();
        }

        function pause(): void {
            root.pause();
        }

        function resume(): void {
            root.resume();
        }

        function toggle(): void {
            root.toggle();
        }

        function add(minutes: int): void {
            root.add(minutes);
        }

        function stop(): void {
            root.stop();
        }
    }
}
