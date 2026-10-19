import QtQuick
import ".."
import "../components"

// Network, Bluetooth and audio as a connected button group, with battery
// beside it on the plain background.
Pill {
    padding: 5
    spacing: 6

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Network {
            first: true
        }
        BluetoothStatus {}
        Audio {
            last: true
        }
    }

    Battery {}
}
