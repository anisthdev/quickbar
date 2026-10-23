import Quickshell
import Quickshell.Bluetooth
import QtQuick
import ".."
import "../components"

// Click for the control panel's Bluetooth page: paired devices, their
// batteries, connecting.
StatusItem {
    id: root

    readonly property bool powered: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length

    // Android has no "off" Bluetooth icon; off is the plain icon, unfilled
    icon: connected > 0 ? "bluetooth_connected" : "bluetooth"
    iconSize: 18
    shape: "Clover4Leaf"
    active: powered
    open: Panels.controlPanel?.openAt === "bluetooth"
    text: Settings.showStatusDetails && powered ? String(connected) : ""

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            Panels.controlPanel?.toggle("bluetooth");
    }

    Tooltip {
        owner: root
        shown: root.hovered && !root.open && !Settings.showStatusDetails
        text: !root.powered ? "Bluetooth off" : root.connected === 1 ? "1 device connected" : `${root.connected} devices connected`
    }
}
