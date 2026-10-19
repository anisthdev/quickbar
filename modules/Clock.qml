import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

// The time half of the clock pill (see Glance). Click for the calendar;
// hover for the full date.
Pill {
    id: root

    padding: 8
    implicitHeight: Theme.barHeight - 10
    anchors.verticalCenter: parent?.verticalCenter
    radius: 8
    color: "transparent"
    clickable: true
    onClicked: menu.toggle()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Monospaced so the pill doesn't change width as the digits change
    Label {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.family: Theme.monoFamily
        font.weight: Font.Black
    }

    Tooltip {
        owner: root
        shown: root.hovered && !menu.open
        text: Qt.locale().toString(clock.date, "dddd, d MMMM yyyy")
    }

    CalendarMenu {
        id: menu
        owner: root
    }

    // `qs -p <dir> ipc call calendar toggle`, e.g. from a Hyprland keybind
    IpcHandler {
        target: "calendar"

        function toggle(): void {
            menu.toggle();
        }
    }
}
