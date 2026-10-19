import Quickshell.Bluetooth
import QtQuick
import ".."
import "../components"

// Connected Bluetooth devices with their battery levels, as a Material 3
// grouped list. Rows are informational only.
Dropdown {
    id: root

    readonly property bool powered: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var devices: Bluetooth.devices.values.filter(d => d.connected)

    // BlueZ's freedesktop icon name -> one of Android's device icons
    function deviceIcon(device) {
        const icon = device.icon ?? "";
        if (/bud|airpod|earbud/i.test(device.name))
            return "bt_earbuds";
        if (icon === "audio-headset")
            return "bt_headset";
        if (icon.startsWith("audio-card") || icon === "audio-headphones")
            return "bt_headphones";
        if (icon === "audio-speakers")
            return "bt_speakers";
        if (icon === "input-mouse" || icon === "input-tablet")
            return "bt_mouse";
        if (icon.startsWith("input-"))
            return "bt_input";
        if (icon === "computer")
            return "bt_laptop";
        return "bt_generic";
    }

    menuWidth: 300

    Label {
        id: heading

        anchors.verticalCenter: undefined
        leftPadding: 12
        topPadding: 6
        bottomPadding: 6
        text: "Connected devices"
        color: Theme.on_surface_variant
        font.pixelSize: 13

        MenuReveal {
            target: heading
            shown: root.open
        }
    }

    Repeater {
        model: root.devices

        ListItem {
            id: row

            required property BluetoothDevice modelData
            required property int index

            icon: root.deviceIcon(modelData)
            text: modelData.name || modelData.deviceName
            first: index === 0
            last: index === root.devices.length - 1
            shown: root.open
            revealIndex: index + 1

            BatteryIcon {
                visible: row.modelData.batteryAvailable
                percent: {
                    const b = row.modelData.battery;
                    return b <= 1 ? b * 100 : b;
                }
                size: 13
                color: Theme.on_surface
            }
        }
    }

    // Empty state
    Rectangle {
        id: empty

        width: parent.width
        height: 56
        radius: 20
        color: Theme.surface_container_high
        visible: root.devices.length === 0

        Label {
            anchors.centerIn: parent
            text: root.powered ? "No devices connected" : "Bluetooth is off"
            color: Theme.on_surface_variant
        }

        MenuReveal {
            target: empty
            shown: root.open
            index: 1
        }
    }
}
