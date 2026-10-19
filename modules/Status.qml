import QtQuick
import ".."
import "../components"

// Network, Bluetooth and audio share one tinted segment, with battery
// sitting on the plain background beside it, like the waybar layout.
Pill {
    padding: 5
    spacing: 0

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: segment.implicitWidth
        implicitHeight: Theme.barHeight - 10
        radius: 8
        color: Theme.inverse_primary

        Behavior on color {
            ColorAnimation {
                duration: Theme.animNormal
            }
        }

        Row {
            id: segment
            anchors.verticalCenter: parent.verticalCenter

            Network {}
            BluetoothStatus {}
            Audio {}
        }
    }

    Battery {}
}
