import Quickshell.Services.UPower
import QtQuick
import ".."
import "../components"

// Android 16 style battery card: the level as a big number over a thick
// progress bar, when it'll run out (or be full), and power mode as a
// Material 3 Expressive connected button group (h/l or 1-3 from the keys).
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
    // h/l step through the power modes, 1-3 pick one
    keyHandler: event => {
        const options = modes.options;
        const at = options.findIndex(o => o.profile === PowerProfiles.profile);
        let to = -1;
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
            to = Math.max(0, at - 1);
        else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
            to = Math.min(options.length - 1, at + 1);
        else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + options.length)
            to = event.key - Qt.Key_1;
        if (to < 0)
            return false;
        PowerProfiles.profile = options[to].profile;
        return true;
    }

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

        // Fills up to the level as the card opens
        LevelBar {
            width: parent.width
            value: root.open ? root.percent / 100 : 0
            duration: 700
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
                property real leftCorners: selected || first ? Theme.radius : 4
                property real rightCorners: selected || last ? Theme.radius : 4

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
