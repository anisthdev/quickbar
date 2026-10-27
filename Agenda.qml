pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Calendar events for the clock's dropdown (CalendarMenu), from the iCal
// feeds listed in ~/.config/quickbar/calendars (e.g. Google Calendar's
// secret address). scripts/calendar fetches them into
// ~/.cache/quickbar/calendar.json, which this reads, so the last events
// show at once and offline. It runs at start, every 15 minutes, and when
// the dropdown opens if the last run is over 5 minutes old.
Singleton {
    id: root

    // "YYYY-MM-DD" → [{ title, start, end, allDay, location }]
    property var days: ({})
    property bool enabled: false
    property real fetched: 0

    function key(date) {
        return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
    }

    function on(date) {
        return days[key(date)] ?? [];
    }

    function refresh() {
        if (!enabled || fetch.running)
            return;
        fetched = Date.now();
        fetch.running = true;
    }

    function refreshIfStale() {
        if (Date.now() - fetched > 5 * 60 * 1000)
            refresh();
    }

    // Whether any feeds are set
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickbar/calendars"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.enabled = text().split("\n").some(l => l.trim() !== "" && !l.trim().startsWith("#"));
            root.fetched = 0;
            root.refresh();
        }
        onLoadFailed: root.enabled = false
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickbar/calendar.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.days = JSON.parse(text()).days ?? {};
            } catch (e) {}
        }
    }

    Process {
        id: fetch

        command: [Quickshell.shellDir + "/scripts/calendar"]
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }
}
