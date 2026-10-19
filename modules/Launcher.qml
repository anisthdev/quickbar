import Quickshell
import QtQuick
import ".."
import "../components"

// The app launcher, as a tonal button: the bar's one standing accent.
Pill {
    padding: 14
    color: Theme.primary_container
    stateColor: Theme.on_primary_container
    clickable: true
    onClicked: Quickshell.execDetached(["rofi", "-show", "drun"])

    Icon {
        name: "archlinux"
        size: 20
        color: Theme.on_primary_container
    }
}
