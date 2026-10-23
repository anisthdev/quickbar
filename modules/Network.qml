import Quickshell
import Quickshell.Networking
import QtQuick
import ".."
import "../components"

// Wi-Fi or Ethernet status from NetworkManager. Click for the control
// panel's Wi-Fi page.
StatusItem {
    id: root

    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var network: wifi?.networks.values.find(n => n.connected) ?? null

    // Android 16 has four Wi-Fi levels, 0-3
    icon: {
        if (network)
            return `wifi_${Math.min(3, Math.floor(network.signalStrength * 4))}`;
        return wired ? "ethernet" : "wifi_off";
    }
    active: network !== null || wired !== null
    open: Panels.controlPanel?.openAt === "wifi"
    iconSize: network ? 13 : wired ? 24 : 17
    readonly property string label: network ? network.name : wired ? "Ethernet" : "Disconnected"

    text: Settings.showStatusDetails ? label : ""

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            Panels.controlPanel?.toggle("wifi");
    }

    Tooltip {
        owner: root
        shown: root.hovered && !root.open && !Settings.showStatusDetails
        text: root.label
    }
}
