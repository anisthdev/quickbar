pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// IPC for the bar's own cards, e.g. `qs -p <dir> ipc call media toggle` from
// a Hyprland keybind. Every monitor has a bar, and a handler in each would
// all claim the same target (only the first one gets calls), so they live
// here once and pass the call on to the bar on the focused monitor.
Singleton {
    id: root

    // Each bar item opens its card when the target is its own and the
    // monitor is the one its bar is on
    signal toggled(string target, string monitor)

    function toggle(target) {
        toggled(target, HyprState.focusedMonitor);
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            root.toggle("media");
        }
    }

    IpcHandler {
        target: "battery"

        function toggle(): void {
            root.toggle("battery");
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.toggle("calendar");
        }
    }

    IpcHandler {
        target: "downloads"

        function toggle(): void {
            root.toggle("downloads");
        }
    }

    IpcHandler {
        target: "weather"

        function toggle(): void {
            root.toggle("weather");
        }
    }

    // The control panel is one window that opens on the focused monitor
    // by itself
    IpcHandler {
        target: "wifi"

        function toggle(): void {
            Panels.controlPanel?.toggle("wifi");
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            Panels.controlPanel?.toggle("bluetooth");
        }
    }

    IpcHandler {
        target: "audio"

        function toggle(): void {
            Panels.controlPanel?.toggle("sound");
        }
    }
}
