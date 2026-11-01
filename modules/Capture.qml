import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The screenshot and screen record menus, in place of the rofi ones: each
// pick runs scripts/screenshot or scripts/screenrecord in
// that mode, once the menu has gone, so a region or window pick starts on a
// clear screen. Opening the record menu while recording stops it instead,
// as the script did.
Scope {
    id: root

    readonly property string scripts: Quickshell.shellDir + "/scripts"

    // From the control panel (fromMenu), with a way back to it
    function showScreenshot(fromMenu) {
        screenshot.show(fromMenu);
    }

    function showRecord(fromMenu) {
        if (record.open)
            return;
        recording.fromMenu = !!fromMenu;
        recording.running = true;
    }

    TileMenu {
        id: screenshot

        title: "Screenshot"
        onBack: Panels.controlPanel?.returnFrom("screenshot")
        entries: [
            {
                label: "Screen",
                icon: "video-display",
                command: [`${root.scripts}/screenshot`, "screen"]
            },
            {
                label: "Region",
                icon: "gnome-screenshot",
                command: [`${root.scripts}/screenshot`, "region"]
            },
            {
                label: "Window",
                icon: "preferences-system-windows",
                command: [`${root.scripts}/screenshot`, "window"]
            },
            {
                label: "In 5 s",
                icon: "xfce4-timer-plugin",
                command: [`${root.scripts}/screenshot`, "timer"]
            }
        ]
    }

    TileMenu {
        id: record

        title: "Screen record"
        onBack: Panels.controlPanel?.returnFrom("record")
        entries: [
            {
                label: "Screen",
                icon: "video-display",
                command: [`${root.scripts}/screenrecord`, "screen"]
            },
            {
                label: "Region",
                icon: "simplescreenrecorder",
                command: [`${root.scripts}/screenrecord`, "region"]
            },
            {
                label: "Window",
                icon: "preferences-system-windows",
                command: [`${root.scripts}/screenrecord`, "window"]
            }
        ]
    }

    // Recording now? Then the record menu's key stops it
    Process {
        id: recording

        property bool fromMenu: false

        command: ["pgrep", "-x", "wl-screenrec|wf-recorder"]
        onExited: code => {
            if (code === 0)
                Quickshell.execDetached([`${root.scripts}/screenrecord`, "stop"]);
            else
                record.show(fromMenu);
        }
    }

    // `qs -c quickbar ipc call screenshot toggle`, e.g. from Print
    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            screenshot.toggle();
        }
    }

    // `qs -c quickbar ipc call record toggle`, e.g. from Alt+Print
    IpcHandler {
        target: "record"

        function toggle(): void {
            if (record.open)
                record.hide();
            else
                root.showRecord();
        }
    }
}
