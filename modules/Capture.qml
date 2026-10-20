import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The screenshot and screen record menus, in place of the rofi ones: each
// pick runs the dotfiles script (menus/screenshot, menus/screenrecord) in
// that mode, once the menu has gone, so a region or window pick starts on a
// clear screen. Opening the record menu while recording stops it instead,
// as the script did.
Scope {
    id: root

    readonly property string menus: Quickshell.env("HOME") + "/.local/bin/menus"

    TileMenu {
        id: screenshot

        title: "Screenshot"
        entries: [
            {
                label: "Screen",
                icon: "screenshot_monitor",
                command: [`${root.menus}/screenshot`, "screen"]
            },
            {
                label: "Region",
                icon: "screenshot_region",
                command: [`${root.menus}/screenshot`, "region"]
            },
            {
                label: "Window",
                icon: "select_window",
                command: [`${root.menus}/screenshot`, "window"]
            },
            {
                label: "In 5 s",
                icon: "timer_5_shutter",
                command: [`${root.menus}/screenshot`, "timer"]
            }
        ]
    }

    TileMenu {
        id: record

        title: "Screen record"
        entries: [
            {
                label: "Screen",
                icon: "screenshot_monitor",
                command: [`${root.menus}/screenrecord`, "screen"]
            },
            {
                label: "Region",
                icon: "screenshot_region",
                command: [`${root.menus}/screenrecord`, "region"]
            },
            {
                label: "Window",
                icon: "select_window",
                command: [`${root.menus}/screenrecord`, "window"]
            }
        ]
    }

    // Recording now? Then the record menu's key stops it
    Process {
        id: recording

        command: ["pgrep", "-x", "wl-screenrec|wf-recorder"]
        onExited: code => {
            if (code === 0)
                Quickshell.execDetached([`${root.menus}/screenrecord`, "stop"]);
            else
                record.show();
        }
    }

    // `qs -p <dir> ipc call screenshot toggle`, e.g. from Print
    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            screenshot.toggle();
        }
    }

    // `qs -p <dir> ipc call record toggle`, e.g. from Alt+Print
    IpcHandler {
        target: "record"

        function toggle(): void {
            if (record.open)
                record.hide();
            else
                recording.running = true;
        }
    }
}
