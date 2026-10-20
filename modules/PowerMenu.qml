import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The power menu, in power-menu's place: lock, suspend, hibernate, restart
// and power off (keys in TileMenu; 1-5 pick directly).
Scope {
    // From the control panel (fromMenu), with a way back to it
    function show(fromMenu) {
        menu.show(fromMenu);
    }

    TileMenu {
        id: menu

        title: "Power"
        onBack: Panels.controlPanel?.returnFrom("power")

        entries: [
            {
                label: "Lock",
                icon: "system-lock-screen",
                command: ["sh", "-c", "pidof hyprlock || systemd-cat -t hyprlock hyprlock"]
            },
            {
                label: "Suspend",
                icon: "system-suspend",
                command: ["sh", "-c", "mpc -q pause; systemctl suspend"]
            },
            {
                label: "Hibernate",
                icon: "system-hibernate",
                command: ["systemctl", "hibernate"]
            },
            {
                label: "Restart",
                icon: "system-reboot",
                command: ["systemctl", "reboot"]
            },
            {
                label: "Power off",
                icon: "system-shutdown",
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
