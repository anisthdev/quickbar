pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Workspace state read from hyprctl. Quickshell's own Hyprland models come
// up empty on Hyprland 0.56 (focused workspace -1, no workspaces until a
// manual refresh), but its event stream works, so events only trigger a
// fresh query here.
Singleton {
    id: root

    property int focusedId: 1
    // id -> { windows, urgent }
    property var workspaces: ({})

    function windows(id) {
        return workspaces[id]?.windows ?? 0;
    }

    readonly property int maxId: Math.max(0, ...Object.keys(workspaces).map(Number).filter(n => n > 0))

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "urgent":
                refresh.urgentAddress = event.data;
                break;
            case "workspacev2":
            case "focusedmonv2":
            case "createworkspacev2":
            case "destroyworkspacev2":
            case "moveworkspacev2":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
                break;
            default:
                return;
            }
            debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: 30
        onTriggered: query.running = true
    }

    QtObject {
        id: refresh
        property string urgentAddress: ""
    }

    Process {
        id: query
        running: true
        command: ["sh", "-c", "hyprctl -j workspaces; echo; hyprctl -j activeworkspace; echo; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Three JSON documents, separated by the echoed newlines
                const parts = text.split(/\n(?=[\[{])/);
                try {
                    const list = JSON.parse(parts[0]);
                    const active = JSON.parse(parts[1]);
                    const clients = JSON.parse(parts[2]);
                    const next = {};
                    for (const ws of list)
                        next[ws.id] = {
                            windows: ws.windows,
                            urgent: false
                        };
                    // An urgent window stops being urgent once its
                    // workspace is visited
                    if (refresh.urgentAddress) {
                        const c = clients.find(c => c.address.endsWith(refresh.urgentAddress));
                        if (c && c.workspace.id !== active.id && next[c.workspace.id])
                            next[c.workspace.id].urgent = true;
                        else
                            refresh.urgentAddress = "";
                    }
                    root.workspaces = next;
                    root.focusedId = active.id;
                } catch (e) {
                    console.warn("HyprState: bad hyprctl output", e);
                }
            }
        }
    }
}
