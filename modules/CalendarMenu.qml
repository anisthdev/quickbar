import Quickshell
import QtQuick
import ".."
import "../components"

// Material 3 docked date picker as the clock's dropdown: today's date as the
// headline, a month bar, and a fixed six-week grid (so the menu never
// changes height) with today filled. The ‹ › buttons or the scroll wheel
// change month, sliding the grid in from that side; "Today" jumps back.
// Below it the timer's presets (TimerState); while one runs, it's at the
// top instead, over the date, with pause, five more minutes and stop.
Dropdown {
    id: root

    readonly property var locale: Qt.locale()
    // Qt numbers weekdays 1 (Monday) to 7 (Sunday); JS dates use 0 for Sunday
    readonly property int firstDay: locale.firstDayOfWeek % 7

    property date today: clock.date
    // First day of the month on show
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property bool onCurrentMonth: month.getFullYear() === today.getFullYear() && month.getMonth() === today.getMonth()

    // The 42 days shown, starting on the locale's first weekday on or
    // before the 1st
    readonly property var days: {
        const lead = (month.getDay() - firstDay + 7) % 7;
        const start = new Date(month.getFullYear(), month.getMonth(), 1 - lead);
        return Array.from({
            length: 42
        }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function showMonth(offset) {
        month = new Date(month.getFullYear(), month.getMonth() + offset, 1);
        slide.from = offset > 0 ? 28 : -28;
        monthAnim.restart();
    }

    function showToday() {
        const forward = today > month;
        month = new Date(today.getFullYear(), today.getMonth(), 1);
        slide.from = forward ? 28 : -28;
        monthAnim.restart();
    }

    // 284 of content: the day grid's width
    menuWidth: 324
    // h/l (or the arrows) the month before or after, t back to today
    keyHandler: event => {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
        case Qt.Key_K:
        case Qt.Key_Up:
            showMonth(-1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
        case Qt.Key_J:
        case Qt.Key_Down:
            showMonth(1);
            return true;
        case Qt.Key_T:
            if (!onCurrentMonth)
                showToday();
            return true;
        }
        return false;
    }

    onOpenChanged: if (open)
        month = new Date(today.getFullYear(), today.getMonth(), 1)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ParallelAnimation {
        id: monthAnim

        NumberAnimation {
            id: slide

            target: grid
            property: "x"
            to: 0
            duration: 250
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        NumberAnimation {
            target: grid
            property: "opacity"
            from: 0
            to: 1
            duration: 150
        }
    }

    // The timer running, over the calendar: how long's left, then pause,
    // more time and stop
    Rectangle {
        id: runningTimer

        visible: TimerState.active
        width: 284
        height: 60
        radius: Theme.radius
        color: Theme.surface_container_high

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            Label {
                anchors.verticalCenter: undefined
                text: TimerState.clock(TimerState.remaining)
                color: TimerState.paused ? Theme.on_surface_variant : Theme.on_surface
                font.pixelSize: 22
                font.weight: Font.Bold
                font.features: {
                    "tnum": 1
                }
            }

            Label {
                anchors.verticalCenter: undefined
                text: TimerState.paused ? `${TimerState.label} · paused` : TimerState.label
                color: Theme.on_surface_variant
                font.pixelSize: 12
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
                implicitWidth: 40
                implicitHeight: 40
                icon: TimerState.paused ? "media_play_arrow" : "media_pause"
                iconSize: 20
                color: Theme.on_surface_variant
                onClicked: TimerState.toggle()
            }

            IconButton {
                implicitWidth: 40
                implicitHeight: 40
                icon: "add"
                iconSize: 20
                color: Theme.on_surface_variant
                onClicked: TimerState.add(5)
            }

            IconButton {
                implicitWidth: 40
                implicitHeight: 40
                icon: "stop"
                iconSize: 20
                color: Theme.on_surface_variant
                onClicked: TimerState.stop()
            }
        }

        MenuReveal {
            target: runningTimer
            shown: root.open
            index: 0
        }
    }

    // Room under it
    Item {
        visible: TimerState.active
        width: 1
        height: 6
    }

    // Headline: today
    Column {
        id: headline

        leftPadding: 12
        topPadding: 4
        bottomPadding: 8

        Label {
            anchors.verticalCenter: undefined
            text: root.today.getFullYear()
            color: Theme.on_surface_variant
            font.pixelSize: 13
        }

        Label {
            anchors.verticalCenter: undefined
            text: root.locale.toString(root.today, "ddd, MMM d")
            color: Theme.on_surface
            font.pixelSize: 26
        }

        MenuReveal {
            target: headline
            shown: root.open
        }
    }

    // Month bar
    Item {
        id: monthBar

        width: parent.width
        height: 40

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 12
            text: root.locale.toString(root.month, "MMMM yyyy")
            color: Theme.on_surface
            font.pixelSize: 14
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Back to this month; only there once you've moved away
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.onCurrentMonth ? 0 : todayLabel.implicitWidth + 24
                height: 32
                radius: Theme.radius
                clip: true
                color: todayMouse.containsMouse ? Theme.primary : Theme.primary_container
                opacity: root.onCurrentMonth ? 0 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.emphasizedDecel
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Label {
                    id: todayLabel

                    anchors.centerIn: parent
                    text: "Today"
                    color: todayMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                    font.pixelSize: 13
                }

                MouseArea {
                    id: todayMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showToday()
                }
            }

            IconButton {
                icon: "chevron"
                onClicked: root.showMonth(-1)
            }

            IconButton {
                icon: "chevron"
                iconRotation: 180
                onClicked: root.showMonth(1)
            }
        }

        MenuReveal {
            target: monthBar
            shown: root.open
            index: 1
        }
    }

    // Weekday initials
    Row {
        id: weekdays

        Repeater {
            model: 7

            Label {
                required property int index

                anchors.verticalCenter: undefined
                width: 284 / 7
                height: 32
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.locale.dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                color: Theme.on_surface_variant
                font.pixelSize: 12
            }
        }

        MenuReveal {
            target: weekdays
            shown: root.open
            index: 2
        }
    }

    // Days. The clip keeps the sliding grid inside the menu's padding.
    Item {
        id: gridArea

        width: 284
        height: grid.implicitHeight
        clip: true

        Grid {
            id: grid

            columns: 7

            Repeater {
                model: root.days

                Item {
                    id: cell

                    required property date modelData
                    readonly property bool isToday: root.sameDay(modelData, root.today)
                    readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()

                    width: 284 / 7
                    height: 40

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        color: cell.isToday ? Theme.primary : Theme.on_surface
                        opacity: cell.isToday ? 1 : dayMouse.containsMouse ? 0.08 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        color: cell.isToday ? Theme.on_primary : Theme.on_surface
                        opacity: cell.inMonth || cell.isToday ? 1 : 0.38
                        font.pixelSize: 13
                        font.weight: cell.isToday ? Font.Bold : Font.Medium
                    }

                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        // Scroll to change month
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.angleDelta.y !== 0)
                    root.showMonth(event.angleDelta.y > 0 ? -1 : 1);
            }
        }

        MenuReveal {
            target: gridArea
            shown: root.open
            index: 3
        }
    }

    // The timer's presets, while none runs
    Column {
        id: timerSection

        visible: !TimerState.active
        width: 284
        topPadding: 14
        spacing: 8

        Label {
            anchors.verticalCenter: undefined
            leftPadding: 4
            text: "Timer"
            color: Theme.on_surface_variant
            font.pixelSize: 13
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    {
                        label: "5 min",
                        minutes: 5
                    },
                    {
                        label: "10 min",
                        minutes: 10
                    },
                    {
                        label: "15 min",
                        minutes: 15
                    },
                    {
                        label: "30 min",
                        minutes: 30
                    },
                    {
                        label: `Focus ${TimerState.focusMinutes}`,
                        focus: true
                    }
                ]

                Rectangle {
                    id: preset

                    required property var modelData

                    width: presetLabel.implicitWidth + 24
                    height: 32
                    radius: 16
                    color: presetMouse.containsMouse ? Theme.secondary_container : Theme.surface_container_high

                    Label {
                        id: presetLabel

                        anchors.centerIn: parent
                        text: preset.modelData.label
                        color: presetMouse.containsMouse ? Theme.on_secondary_container : Theme.on_surface
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: presetMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: preset.modelData.focus ? TimerState.focus() : TimerState.start(preset.modelData.minutes)
                    }
                }
            }
        }

        MenuReveal {
            target: timerSection
            shown: root.open
            index: 4
        }
    }
}
