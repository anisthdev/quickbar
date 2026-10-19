import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import ".."
import "../components"

// The bar's battery. Click for the battery card, hover for the level and
// time left.
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

    // Hover state layer
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.on_surface
        opacity: mouse.pressed ? 0.12 : mouse.containsMouse || card.open ? 0.08 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }
    }

    BatteryIcon {
        id: icon
        anchors.centerIn: parent
        percent: root.percent
        charging: root.charging
        color: Theme.on_background
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.toggle()
    }

    Tooltip {
        owner: root
        shown: mouse.containsMouse && !card.open
        text: `${Math.round(root.percent)}% · ${card.status}`
    }

    BatteryCard {
        id: card
        owner: root
    }

    // `qs -p <dir> ipc call battery toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "battery"

        function toggle(): void {
            card.toggle();
        }
    }
}
