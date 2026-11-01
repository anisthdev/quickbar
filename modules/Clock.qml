import Quickshell
import QtQuick
import ".."
import "../components"

// The time half of the clock pill (see Glance), and the timer while one
// runs (TimerState), after a hairline: the time left in the accent
// colour, a bar under it of how much. Click for the calendar, with the timer's controls;
// middle-click pauses or resumes the timer; hover for the full date.
Pill {
    id: root

    padding: 8
    // The timer and its hairline as far apart as the weather's
    spacing: 9
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

    // Tabular digits, so the pill doesn't change width as they change
    Label {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.weight: Font.Bold
        roundness: Theme.titleRoundness
        font.features: {
            "tnum": 1
        }
    }

    // The same hairline as between the weather and the time
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: TimerState.active
        width: 1
        height: 16
        color: Theme.on_background
        opacity: 0.3
    }

    // The timer: a break in the secondary colour, paused in the outline's;
    // what's left as a bar under it, below the digits so they line up with
    // the time
    Item {
        id: timer

        readonly property color tint: TimerState.paused ? Theme.outline : TimerState.kind === "break" ? Theme.secondary : Theme.primary

        anchors.verticalCenter: parent.verticalCenter
        visible: TimerState.active
        width: timerLabel.implicitWidth
        height: timerLabel.implicitHeight

        Label {
            id: timerLabel

            text: TimerState.clock(TimerState.remaining)
            color: timer.tint
            font.weight: Font.Bold
            roundness: Theme.titleRoundness
            font.features: {
                "tnum": 1
            }
        }

        Rectangle {
            anchors.top: parent.bottom
            anchors.topMargin: 1
            width: parent.width
            height: 2
            radius: 1
            color: Qt.rgba(timer.tint.r, timer.tint.g, timer.tint.b, 0.3)

            Rectangle {
                width: parent.width * TimerState.progress
                height: parent.height
                radius: 1
                color: timer.tint
            }
        }
    }

    // Middle-click: pause or resume the timer (a handler, as items in a
    // Pill are laid out in its row)
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        enabled: TimerState.active
        onTapped: TimerState.toggle()
    }

    Tooltip {
        owner: root
        shown: root.hovered && !menu.open
        text: Qt.locale().toString(clock.date, "dddd, d MMMM yyyy")
        description: !TimerState.active ? "" : TimerState.paused ? `${TimerState.label} paused · middle-click to resume` : `${TimerState.label} · middle-click to pause`
    }

    CalendarMenu {
        id: menu
        owner: root
    }

    // `qs -c quickbar ipc call calendar toggle`, through BarIpc: only the bar on
    // the focused monitor opens it
    Connections {
        target: BarIpc
        function onToggled(name, monitor) {
            if (name === "calendar" && monitor === root.QsWindow.window?.screen?.name)
                menu.toggle();
        }
    }
}
