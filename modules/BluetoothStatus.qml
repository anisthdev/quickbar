import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// Click for connected devices and their batteries, right-click for the
// control panel's Bluetooth page (pairing and so on).
StatusItem {
    id: root

    readonly property bool powered: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length

    // Android has no "off" Bluetooth icon; off is the plain icon, unfilled
    icon: connected > 0 ? "bluetooth_connected" : "bluetooth"
    iconSize: 18
    active: powered
    open: menu.open
    text: Settings.showStatusDetails && powered ? String(connected) : ""

    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            return;
        if (event.button === Qt.RightButton)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/menus/control-panel-script", "--page", "bluetooth"]);
        else
            menu.toggle();
    }

    BluetoothMenu {
        id: menu
        owner: root
    }

    Tooltip {
        owner: root
        shown: root.hovered && !menu.open && !Settings.showStatusDetails
        text: !root.powered ? "Bluetooth off" : root.connected === 1 ? "1 device connected" : `${root.connected} devices connected`
    }

    // `qs -p <dir> ipc call bluetooth toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            menu.toggle();
        }
    }
}
