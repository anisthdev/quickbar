import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Keep awake, in toggle-idle's place: while on, the session doesn't go idle,
// so hypridle neither dims, locks, blanks nor suspends. It holds Wayland's
// idle inhibitor on a window of its own: a pixel, invisible, mapped only
// while it's on. It's off again whenever quickbar starts.
//
// The control panel switches it; so does Super+Ctrl+I (`… ipc call
// keepawake toggle`), which says so in a notification.
Scope {
    id: root

    property bool on: false

    function toggle() {
        on = !on;
    }

    PanelWindow {
        id: holder

        visible: root.on
        anchors {
            top: true
            left: true
        }
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "quickbar-keepawake"
        WlrLayershell.layer: WlrLayer.Background

        IdleInhibitor {
            window: holder
            enabled: root.on
        }
    }

    IpcHandler {
        target: "keepawake"

        function toggle(): void {
            root.toggle();
            Quickshell.execDetached(["notify-send", "-i", "caffeine", "-h", "string:x-canonical-private-synchronous:keepawake", "Keep awake", root.on ? "On: the screen stays on and unlocked" : "Off"]);
        }

        function isOn(): bool {
            return root.on;
        }
    }
}
