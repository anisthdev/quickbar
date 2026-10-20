import QtQuick
import ".."
import "../components"

// Network, Bluetooth and audio in one pill, as icons unless their details
// are on (middle-click any of them), with battery beside it.
Pill {
    padding: 5
    spacing: 6

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        // The buttons animate their own widths; this follows them
        implicitWidth: buttons.implicitWidth
        implicitHeight: Theme.barHeight - 10
        radius: 8
        color: Theme.surface_container_highest

        Row {
            id: buttons

            anchors.verticalCenter: parent.verticalCenter

            Network {}
            BluetoothStatus {}
            Audio {}
        }
    }

    Battery {}
}
