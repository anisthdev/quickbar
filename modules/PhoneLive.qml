import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The phone's Live Updates (a delivery's "4 mins", a call's timer) from
// handoffd, as an Android 16 style chip: the app's icon and the chip text.
// handoffd keeps the live items in $XDG_RUNTIME_DIR/handoff/live.json,
// newest first; this watches that file, so it needs no refresh signal, and
// ticks timer chips itself. It pops in when something goes live, rolls its
// text as it changes and shrinks away when nothing is live.
Item {
    id: root

    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/handoff"

    property var items: []
    property int daemonPid: 0
    property bool daemonAlive: false
    readonly property var live: daemonAlive ? items : []

    // The chip on show; kept while the pill shrinks away
    property var shown: null
    onLiveChanged: if (live.length > 0)
        shown = live[0]

    // Ticks while a timer chip is showing
    property date now: new Date()

    // Port of handoffd's Item.Text: the app's text, or for a timer chip the
    // time since (or until) its start as MM:SS, with hours past one
    function chipText(item) {
        if (!item)
            return "";
        if (item.chip !== "" || !item.chrono)
            return item.chip;
        let seconds = Math.floor((now - new Date(item.chrono)) / 1000);
        if (item.countdown)
            seconds = -seconds;
        seconds = Math.max(0, seconds);
        const pad = n => String(n).padStart(2, "0");
        if (seconds >= 3600)
            return `${Math.floor(seconds / 3600)}:${pad(Math.floor(seconds / 60) % 60)}:${pad(seconds % 60)}`;
        return `${pad(Math.floor(seconds / 60))}:${pad(seconds % 60)}`;
    }

    // 0 = gone, 1 = fully there
    property real presence: 0

    implicitWidth: pill.implicitWidth * Math.max(0, presence)
    implicitHeight: Theme.barHeight
    visible: presence > 0

    states: State {
        when: root.live.length > 0
        PropertyChanges {
            root.presence: 1
        }
    }
    transitions: [
        Transition {
            to: ""
            NumberAnimation {
                property: "presence"
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedAccel
            }
        },
        Transition {
            from: ""
            NumberAnimation {
                property: "presence"
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
    ]

    FileView {
        id: liveFile

        path: root.runDir + "/live.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.items = JSON.parse(text()) ?? [];
            } catch (e) {
                root.items = [];
            }
        }
        // No file means nothing has gone live since the daemon started
        onLoadFailed: root.items = []
    }

    FileView {
        id: statusFile

        path: root.runDir + "/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.daemonPid = JSON.parse(text()).pid ?? 0;
            } catch (e) {
                root.daemonPid = 0;
            }
        }
        onLoadFailed: root.daemonPid = 0
    }

    // A live.json left behind by a daemon that died shouldn't show a chip,
    // so check the daemon is still there
    FileView {
        id: daemonComm

        path: root.daemonPid > 0 ? `/proc/${root.daemonPid}/comm` : ""
        printErrors: false
        onLoaded: root.daemonAlive = text().trim() === "handoffd"
        onLoadFailed: root.daemonAlive = false
    }

    // The daemon replaces live.json by renaming over it, which file
    // watching can miss, and its process can vanish without a file change:
    // re-read both now and then
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            liveFile.reload();
            if (root.daemonPid > 0)
                daemonComm.reload();
            else
                root.daemonAlive = false;
        }
    }

    Timer {
        interval: 1000
        running: root.live.some(i => i.chip === "" && i.chrono)
        repeat: true
        // Fresh as soon as a timer appears, not a second later
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Pill {
        id: pill

        anchors.verticalCenter: parent.verticalCenter
        padding: 10
        spacing: 7
        color: Theme.primary_container
        stateColor: Theme.on_primary_container
        clickable: true
        scale: Math.max(0, root.presence)
        transformOrigin: Item.Left
        onClicked: Quickshell.execDetached(["hyprctl", "eval", "require(\"scratchpads.phone\").toggle()"])

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: (root.shown?.icon ?? "") !== ""
            source: root.shown?.icon ? `file://${root.shown.icon}` : ""
            sourceSize: Qt.size(20, 20)
            smooth: true
        }

        RollingText {
            text: root.chipText(root.shown)
            color: Theme.on_primary_container
        }

        Tooltip {
            owner: pill
            shown: pill.hovered
            text: root.shown ? `${root.shown.app} · ${root.chipText(root.shown)}` : ""
            // The newest chip's title, then any other live chips
            description: [root.shown?.title ?? ""].concat(root.live.slice(1).map(i => `${i.app} · ${root.chipText(i)}`)).filter(l => l !== "").join("\n")
        }
    }
}
