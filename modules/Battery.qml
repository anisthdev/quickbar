import Quickshell.Services.UPower
import QtQuick
import ".."
import "../components"

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property real percent: {
        const p = device?.percentage ?? 0;
        return p <= 1 ? p * 100 : p;
    }
    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.FullyCharged

    visible: device?.isLaptopBattery ?? false
    implicitWidth: icon.implicitWidth + 20
    implicitHeight: Theme.barHeight - 10
    anchors.verticalCenter: parent?.verticalCenter

    BatteryIcon {
        id: icon
        anchors.centerIn: parent
        percent: root.percent
        charging: root.charging
        color: Theme.on_background
    }
}
