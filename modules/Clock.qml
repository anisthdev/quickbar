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
    color: hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    clickable: true
    onClicked: menu.toggle()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        text: Qt.formatDateTime(clock.date, "hh:mm AP")
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
