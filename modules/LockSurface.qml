import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."
import "../components"
import "LockShapes.js" as LockShapes

// One screen of the lock screen (see LockScreen), after end-4's: the
// wallpaper blurred and dimmed, the large stacked clock with the date at
// the top, and along the bottom three pills: who it is; the fingerprint,
// the password field (a Material shape per character) and its button; the battery, sleep, power off and restart. Typing goes to the
// field from anywhere: Enter checks (Ctrl+Enter also turns on Keep awake),
// Backspace takes one back (Ctrl+Backspace or Ctrl+U all), Esc clears, or
// leaves power off and restart for unlocking (and closes a preview when
// empty).
Item {
    id: root

    required property var lock

    readonly property color base: solid(Theme.background)
    readonly property var battery: UPower.displayDevice
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged
    readonly property bool ctrlHeld: held.ctrl

    // The field's shake, an offset in pixels
    property real shakeX: 0

    function solid(c) {
        return Qt.rgba(c.r, c.g, c.b, 1);
    }

    focus: true
    Component.onCompleted: forceActiveFocus()

    QtObject {
        id: held

        property bool ctrl: false
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control)
            held.ctrl = false;
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Control:
            held.ctrl = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            lock.submit(ctrl);
            break;
        case Qt.Key_Backspace:
            ctrl ? lock.clear() : lock.backspace();
            break;
        case Qt.Key_U:
            if (!ctrl)
                return typeText(event);
            lock.clear();
            break;
        case Qt.Key_Escape:
            if (lock.password === "" && lock.target !== "unlock")
                lock.aim(lock.target);
            else if (lock.password === "" && lock.previewing)
                lock.unlock();
            lock.clear();
            break;
        default:
            return typeText(event);
        }
        event.accepted = true;
    }

    function typeText(event) {
        const text = event.text;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        if (text === "" || text.charCodeAt(0) < 32 || text.charCodeAt(0) === 127)
            return;
        lock.type(text);
        event.accepted = true;
    }

    Connections {
        target: root.lock
        function onShake() {
            shakeAnim.restart();
        }
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: root
            property: "shakeX"
            to: -14
            duration: 50
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 12
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: -8
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 4
            duration: 60
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "shakeX"
            to: 0
            duration: 50
            easing.type: Easing.OutQuad
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Opaque from the first frame: nothing of the desktop shows through
    Rectangle {
        anchors.fill: parent
        color: root.base
    }

    // The wallpaper, settling in from a little larger as the screen shows
    Image {
        id: wallpaper

        anchors.fill: parent
        source: root.lock.wallpaper ? "file://" + root.lock.wallpaper : ""
        sourceSize.width: root.width
        sourceSize.height: root.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        scale: 1.08 - 0.08 * root.lock.reveal
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        scale: wallpaper.scale
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.25
        opacity: wallpaper.status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // A scrim, so the clock reads on any wallpaper
    Rectangle {
        anchors.fill: parent
        color: root.base
        opacity: 0.35
    }

    // The clock, hours over minutes, then the date
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.08 - 60 * (1 - root.lock.reveal)
        opacity: root.lock.reveal
        // The digits' own line gap is generous; the minutes tuck under
        spacing: -30

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            text: Qt.formatDateTime(clock.date, "HH")
            color: Theme.primary
            font.pixelSize: 120
            font.weight: 650
            roundness: 100
            font.features: {
                "tnum": 1
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            text: Qt.formatDateTime(clock.date, "mm")
            color: Theme.tertiary_fixed
            font.pixelSize: 120
            font.weight: 650
            roundness: 100
            font.features: {
                "tnum": 1
            }
        }

        Item {
            width: 1
            height: 62
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.on_surface
            font.pixelSize: 24
        }
    }

    // The toolbar, rising and scaling in as the lock shows
    Row {
        id: toolbar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 - 40 * (1 - root.lock.reveal)
        spacing: 10
        opacity: root.lock.reveal
        scale: 0.9 + 0.1 * root.lock.reveal

        // Who it is: the picture (~/.face), round, or an icon without one
        Island {

            IslandRow {
                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: width / 2
                    color: "transparent"

                    Image {
                        id: face

                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face"
                        sourceSize.width: 44
                        sourceSize.height: 44
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: face.status === Image.Error
                        name: "person"
                        size: 22
                        color: Theme.on_surface_variant
                    }
                }

                Label {
                    rightPadding: 6
                    text: root.lock.userName
                    color: Theme.on_surface_variant
                    font.pixelSize: 15
                }
            }
        }

        // The fingerprint, the field and its button
        Island {
            id: main

            transform: Translate {
                x: root.shakeX
            }

            IslandRow {
                leftPadding: root.lock.finger === "off" ? 8 : 14
                rightPadding: 6

                Icon {
                    visible: root.lock.finger !== "off"
                    name: "fingerprint"
                    size: 26
                    color: root.lock.finger === "failed" ? Theme.error : Theme.on_surface_variant
                }

                Item {
                    id: field

                    width: 260
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        visible: root.lock.password === ""
                        text: {
                            if (root.lock.message !== "")
                                return root.lock.message;
                            if (root.lock.target === "poweroff")
                                return "Password to power off";
                            if (root.lock.target === "reboot")
                                return "Password to restart";
                            return root.lock.finger === "off" ? "Enter password" : "Password or fingerprint";
                        }
                        color: root.lock.message !== "" ? Theme.error : Theme.on_surface_variant
                        font.pixelSize: 15
                    }

                    // A shape per character, each springing in (in the
                    // accent, settling to the text colour) and out
                    ListView {
                        id: dots

                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(contentWidth, parent.width - 8)
                        height: 18
                        orientation: ListView.Horizontal
                        spacing: 4
                        interactive: false
                        clip: true
                        model: root.lock.dots
                        onCountChanged: positionViewAtEnd()
                        delegate: Item {
                            id: cell

                            required property int index

                            width: 18
                            height: 18
                            opacity: root.lock.checking ? 0.5 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            GlyphShape {
                                // -1 while it goes
                                d: LockShapes.shapes[Math.max(0, cell.index) % LockShapes.shapes.length]
                                unit: 18 / 100
                                fill: Theme.primary

                                ColorAnimation on fill {
                                    to: Theme.on_surface
                                    duration: 1000
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        add: Transition {
                            NumberAnimation {
                                property: "scale"
                                from: 0
                                to: 1
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.5
                            }
                        }
                        remove: Transition {
                            NumberAnimation {
                                property: "scale"
                                to: 0
                                duration: 120
                            }
                        }
                        displaced: Transition {
                            NumberAnimation {
                                property: "x"
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                // Unlock (a cup with Ctrl held: and keep awake), or power off
                // or restart; the check going on
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.lock.checking ? root.solid(Theme.surface_container_highest) : root.solid(Theme.primary)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !root.lock.checking
                        name: root.lock.target === "poweroff" ? "power_settings_new" : root.lock.target === "reboot" ? "restart_alt" : root.ctrlHeld ? "coffee" : "arrow_forward"
                        size: 24
                        color: root.solid(Theme.on_primary)
                    }

                    CircularProgress {
                        anchors.centerIn: parent
                        visible: root.lock.checking
                        indeterminate: true
                        size: 22
                        thickness: 3
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lock.submit(false)
                    }
                }
            }
        }

        // The battery, sleep, power off and restart
        Island {

            IslandRow {
                rightPadding: 6

                // Android's battery, the percentage inside; a bolt while
                // charging
                Item {
                    visible: root.battery?.isLaptopBattery ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: batteryIcon.implicitWidth + 6
                    implicitHeight: batteryIcon.implicitHeight

                    BatteryIcon {
                        id: batteryIcon

                        percent: {
                            const p = root.battery?.percentage ?? 0;
                            return p <= 1 ? p * 100 : p;
                        }
                        charging: root.charging
                        color: Theme.on_surface_variant
                        size: 16
                    }
                }

                ToolButton {
                    icon: "dark_mode"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mpc -q pause; systemctl suspend"])
                }

                ToolButton {
                    icon: "power_settings_new"
                    toggled: root.lock.target === "poweroff"
                    onClicked: root.lock.aim("poweroff")
                }

                ToolButton {
                    icon: "restart_alt"
                    toggled: root.lock.target === "reboot"
                    onClicked: root.lock.aim("reboot")
                }
            }
        }
    }

    // One of the toolbar's pills
    component Island: Rectangle {
        // Inline components don't see root's solid()
        implicitWidth: childrenRect.width
        height: 56
        radius: height / 2
        color: Qt.rgba(Theme.surface_container_high.r, Theme.surface_container_high.g, Theme.surface_container_high.b, 1)
    }

    // An island's contents, padded and centred
    component IslandRow: Row {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 14
        rightPadding: 14
        spacing: 10
    }

    component ToolButton: IconButton {
        property bool toggled: false
        // Inline components don't see root's
        readonly property color primary: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 1)

        implicitWidth: 44
        implicitHeight: 44
        iconSize: 22
        color: toggled ? Qt.rgba(Theme.on_primary.r, Theme.on_primary.g, Theme.on_primary.b, 1) : Theme.on_surface_variant

        Rectangle {
            z: -1
            anchors.fill: parent
            radius: width / 2
            color: parent.primary
            opacity: parent.toggled ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }
}
