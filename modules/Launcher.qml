import QtQuick
import ".."
import "../components"

// The app launcher's button, tonal: the bar's one standing accent.
Pill {
    required property var apps

    padding: 14
    color: Theme.primary_container
    stateColor: Theme.on_primary_container
    clickable: true
    onClicked: apps.toggle()

    Icon {
        name: "archlinux"
        size: 20
        color: Theme.on_primary_container
    }
}
