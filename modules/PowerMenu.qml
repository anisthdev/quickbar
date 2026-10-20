import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// The power menu, in power-menu's place: lock, suspend, hibernate, restart
// and power off (keys in TileMenu; 1-5 pick directly).
Scope {
    TileMenu {
        id: menu

        entries: [
            {
                label: "Lock",
                icon: "lock_screen",
                command: ["sh", "-c", "pidof hyprlock || systemd-cat -t hyprlock hyprlock"]
            },
            {
                label: "Suspend",
                icon: "bedtime",
                command: ["sh", "-c", "mpc -q pause; systemctl suspend"]
            },
            {
                label: "Hibernate",
                icon: "ac_unit",
                command: ["systemctl", "hibernate"]
            },
            {
                label: "Restart",
                icon: "restart",
                command: ["systemctl", "reboot"]
            },
            {
                label: "Power off",
                icon: "power_off",
                command: ["systemctl", "poweroff"]
            }
        ]
    }

    // `qs -p <dir> ipc call power toggle`, e.g. from Super+Escape
    IpcHandler {
        target: "power"

        function toggle(): void {
            menu.toggle();
        }
    }
}
