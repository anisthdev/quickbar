import Quickshell.Services.UPower
import QtQuick
import ".."
import "../components"

// Android 16 style battery card: the level as a big number over a thick
// progress bar, when it'll run out (or be full), and power mode as a
// Material 3 Expressive connected button group.
Dropdown {
    id: root

    readonly property var device: UPower.displayDevice

    readonly property real percent: {
        const p = device?.percentage ?? 0;
        return p <= 1 ? p * 100 : p;
    }
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool notCharging: state === UPowerDeviceState.PendingCharge

    // "Until 4:45 PM", "Full by 5:30 PM"…; also the bar battery's tooltip
    readonly property string status: {
        const at = seconds => Qt.formatTime(new Date(Date.now() + seconds * 1000), "h:mm AP");
        if (full)
            return "Fully charged";
        if (notCharging)
            return "Plugged in, not charging";
        if (charging)
            return device.timeToFull > 0 ? `Full by ${at(device.timeToFull)}` : "Charging";
        return device?.timeToEmpty > 0 ? `Until ${at(device.timeToEmpty)}` : "On battery";
    }

    menuWidth: 340
    title: "Battery"

    // Level and bar
    Column {
        id: level

        width: parent.width
        spacing: 8

        Row {
            leftPadding: 8

            Label {
                id: number

                anchors.verticalCenter: undefined
                text: Math.round(root.percent)
                color: Theme.on_surface
                font.pixelSize: 56
                font.weight: Font.Normal
            }

            Label {
                anchors.verticalCenter: undefined
                anchors.baseline: number.baseline
                text: "%"
                color: Theme.on_surface
                font.pixelSize: 18
                font.weight: Font.Normal
            }
        }

        // Filled part, a small gap, then the rest of the track with a stop
        // dot; round outer ends, tight inner edges
        Item {
            id: bar

            readonly property real outer: height * 0.38
            readonly property real inner: 3
            readonly property real gap: 4
            // Fills up to the level as the card opens
            property real shown: root.open ? Math.max(0, Math.min(100, root.percent)) / 100 : 0
            readonly property real fillWidth: Math.max(outer, shown * (width - gap))

            width: parent.width
            height: 40

            Behavior on shown {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }

            Rectangle {
                width: bar.fillWidth
                height: parent.height
                topLeftRadius: bar.outer
                bottomLeftRadius: bar.outer
                topRightRadius: bar.shown >= 1 ? bar.outer : bar.inner
                bottomRightRadius: bar.shown >= 1 ? bar.outer : bar.inner
                color: Theme.primary
            }

            Rectangle {
                x: bar.fillWidth + bar.gap
                width: Math.max(0, parent.width - x)
                height: parent.height
                visible: width > 0
                topLeftRadius: bar.inner
                bottomLeftRadius: bar.inner
                topRightRadius: bar.outer
                bottomRightRadius: bar.outer
                color: Theme.primary_container

                // Stop indicator
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.width > 30
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.primary
                }
            }
        }

        Label {
            anchors.verticalCenter: undefined
            leftPadding: 8
            bottomPadding: 6
            text: root.status
            color: Theme.on_surface
            font.pixelSize: 14
            font.weight: Font.Normal
        }

        MenuReveal {
            target: level
            shown: root.open
            index: 1
        }
    }

    // Connected button group: rounded outer corners, tight inner ones; the
    // selected button fills and rounds all its corners
    Row {
        id: modes

        readonly property var options: [
            {
                profile: PowerProfile.PowerSaver,
                icon: "power_energy_savings_leaf",
                label: "Saver"
            },
            {
                profile: PowerProfile.Balanced,
                icon: "power_balance",
                label: "Balanced"
            },
            {
                profile: PowerProfile.Performance,
                icon: "power_speed",
                label: "Performance"
            }
        ].filter(o => o.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

        width: parent.width
        spacing: 3

        Repeater {
            model: modes.options

            Rectangle {
                id: mode

                required property var modelData
                required property int index
                readonly property bool selected: PowerProfiles.profile === modelData.profile
                readonly property bool first: index === 0
                readonly property bool last: index === modes.options.length - 1
                property real leftCorners: selected || first ? 20 : 6
                property real rightCorners: selected || last ? 20 : 6

                width: (modes.width - modes.spacing * (modes.options.length - 1)) / modes.options.length
                height: 64
                topLeftRadius: leftCorners
                bottomLeftRadius: leftCorners
                topRightRadius: rightCorners
                bottomRightRadius: rightCorners
                color: selected ? Theme.primary : modeMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                Behavior on leftCorners {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on rightCorners {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animNormal
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: undefined
                        name: mode.modelData.icon
                        size: 20
                        color: mode.selected ? Theme.on_primary : Theme.on_surface
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: undefined
                        text: mode.modelData.label
                        color: mode.selected ? Theme.on_primary : Theme.on_surface
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: modeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfiles.profile = mode.modelData.profile
                }
            }
        }

        MenuReveal {
            target: modes
            shown: root.open
            index: 2
        }
    }

    // Why Performance is being held back, when it is
    Label {
        anchors.verticalCenter: undefined
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        width: parent.width
        leftPadding: 12
        text: PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature ? "Performance is limited: the laptop is hot" : "Performance is limited: the laptop is on your lap"
        color: Theme.error
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
