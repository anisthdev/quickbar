import Quickshell.Hyprland
import QtQuick
import ".."
import "../components"

Pill {
    id: root

    // Always show 1-5, plus any higher workspace that currently exists
    readonly property int count: Math.max(5, HyprState.maxId)

    padding: 10
    spacing: 10

    Repeater {
        model: root.count

        Rectangle {
            id: button

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: HyprState.focusedId === wsId
            readonly property bool occupied: HyprState.windows(wsId) > 0
            readonly property bool urgent: HyprState.workspaces[wsId]?.urgent ?? false

            width: active ? 47 : 32
            height: Theme.barHeight - 10
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radius
            color: {
                if (urgent)
                    return Theme.error;
                if (active)
                    return Theme.inverse_primary;
                if (mouse.containsMouse)
                    return Theme.surface_container_low;
                if (occupied)
                    return Theme.surface_container_highest;
                return "transparent";
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animNormal
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.wsId
                color: button.urgent ? Theme.on_error : button.active ? Theme.on_surface : button.occupied ? Theme.inverse_surface : Theme.outline
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hyprland's Lua config takes dispatchers as Lua expressions
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${button.wsId} })`)
            }
        }
    }
}
