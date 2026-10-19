import Quickshell
import Quickshell.Wayland
import QtQuick
import "modules"

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 5
        left: 5
        right: 5
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    // Hyprland's blur layer rule matches on this name
    WlrLayershell.namespace: "quickbar"

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Launcher {}
        Clock {}
        Workspaces {}
        Weather {}
        Submap {}
    }

    WindowTitle {
        anchors.centerIn: parent
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Tray {
            bar: bar
        }
        Status {}
    }
}
