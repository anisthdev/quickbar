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

    // The app launcher, for the launcher button
    required property var apps

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Launcher {
            apps: bar.apps
        }
        Glance {}
        Workspaces {}
        PhoneLive {}
        Mpd {}
        // The 5-hour window; the weekly one on hover
        Meter {
            source: "claude"
            icon: "claude"
            title: "Claude Code"
            // Claude's brand colour
            color: "#d97757"
        }
        Submap {}
    }

    WindowTitle {
        anchors.centerIn: parent
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Tasks {}
        Downloads {}
        Tray {}
        Status {}
    }
}
