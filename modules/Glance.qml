import QtQuick
import ".."
import "../components"

// Weather, time and the to-do count in one pill, split by hairlines: the
// condition icon opens the weather card, the time opens the calendar, the
// count the to-do list.
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

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: tasks.visible
        width: 1
        height: 16
        color: Theme.on_background
        opacity: 0.3
    }

    Tasks {
        id: tasks
    }
}
