import Quickshell.Hyprland
import QtQuick
import ".."
import "../components"

Pill {
    id: root

    property string submap: ""

    color: Theme.tertiary_container
    visible: submap !== ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap")
                root.submap = event.data;
        }
    }

    Icon {
        name: "keyboard_command_key"
        size: 16
        color: Theme.on_tertiary_container
    }

    Label {
        text: root.submap
        color: Theme.on_tertiary_container
    }
}
