import Quickshell
import QtQuick
import "../components"

Pill {
    id: root

    property bool expanded: false

    padding: 8
    clickable: true
    onClicked: expanded = !expanded

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        text: Qt.formatDateTime(clock.date, root.expanded ? "ddd, d. MMM  hh:mm AP" : "hh:mm AP")
    }
}
