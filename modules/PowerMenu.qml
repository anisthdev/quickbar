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
        onActivated: entry => {
            if (entry.lock)
                Panels.lockScreen?.lock();
        }

        entries: [
            {
                label: "Lock",
                icon: "system-lock-screen",
                // The lock screen, in this same shell (onActivated)
                lock: true
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

    // `qs -c quickbar ipc call power toggle`, e.g. from Super+Escape
    IpcHandler {
        target: "power"

        function toggle(): void {
            menu.toggle();
        }
    }
}
