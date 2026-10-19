import QtQuick
import ".."
import "../components"

// Weather and time in one pill, split by a hairline: the condition icon
// opens the weather card, the time opens the calendar.
Pill {
    padding: 5
    spacing: 2

    Weather {
        id: weather
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: weather.visible
        width: 1
        height: 16
        color: Theme.on_background
        opacity: 0.3
    }

    Clock {}
}
