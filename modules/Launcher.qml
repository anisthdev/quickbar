import Quickshell
import QtQuick
import "../components"

Pill {
    padding: 14
    clickable: true
    onClicked: Quickshell.execDetached(["rofi", "-show", "drun"])

    Icon {
        name: "archlinux"
        size: 20
        color: "#4b91bb"
    }
}
