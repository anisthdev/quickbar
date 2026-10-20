import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."
import "../components"

// One screen of the lock screen (see LockScreen), after Android's: the
// wallpaper blurred and dimmed, the large stacked clock with the date
// under it, and at the bottom the password field, the fingerprint and, when
// charging, the battery. Typing goes to the field from anywhere: Enter
// checks, Backspace takes one back (Ctrl+Backspace or Ctrl+U all), Esc
// clears (and closes a preview when empty).
Item {
    id: root

    required property var lock

    readonly property color base: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
    readonly property var battery: UPower.displayDevice
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged

    // The field's shake, an offset in pixels
    property real shakeX: 0

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            lock.submit();
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
            if (lock.password === "" && lock.previewing)
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

    // The battery, at the top right as in Android's status bar
    BatteryIcon {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 28
        anchors.verticalCenter: undefined
        visible: root.battery?.isLaptopBattery ?? false
        percent: {
            const p = root.battery?.percentage ?? 0;
            return p <= 1 ? p * 100 : p;
        }
        charging: root.charging
        size: 18
        opacity: root.lock.reveal
    }

    // Who it is, the field, what it says and the fingerprint, below the
    // middle
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.height * 0.14 + 80 * (1 - root.lock.reveal)
        opacity: root.lock.reveal
        spacing: 18

        // The picture (~/.face), round
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104
            radius: width / 2
            color: Theme.surface_container_high

            Image {
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.face"
                sourceSize.width: 208
                sourceSize.height: 208
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            topPadding: -6
            bottomPadding: 6
            text: root.lock.userName
            color: Theme.on_surface
            font.pixelSize: 24
            font.weight: Theme.titleWeight
            roundness: Theme.titleRoundness
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.shakeX
            width: 340
            height: 46
            radius: height / 2
            color: Theme.surface_container_high
            border.width: root.lock.message !== "" ? 2 : 0
            border.color: Theme.error

            // A lock, or the check going on
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24

                Icon {
                    anchors.centerIn: parent
                    visible: !root.lock.checking
                    name: "lock"
                    size: 22
                    color: root.lock.message !== "" ? Theme.error : Theme.on_surface_variant
                }

                CircularProgress {
                    anchors.centerIn: parent
                    visible: root.lock.checking
                    indeterminate: true
                    size: 22
                    thickness: 3
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.lock.password === ""
                text: "Password"
                color: Theme.on_surface_variant
                font.pixelSize: 16
            }

            // A dot per character, each springing in and out
            ListView {
                id: dots

                anchors.centerIn: parent
                width: Math.min(contentWidth, parent.width - 120)
                height: 11
                orientation: ListView.Horizontal
                spacing: 8
                interactive: false
                clip: true
                model: root.lock.dots
                onCountChanged: positionViewAtEnd()
                delegate: Rectangle {
                    width: 11
                    height: 11
                    radius: 5.5
                    color: Theme.on_surface
                    opacity: root.lock.checking ? 0.5 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animFast
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

        // What went wrong, or how to unlock
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            text: root.lock.message !== "" ? root.lock.message : root.lock.finger === "off" ? "Type your password to unlock" : "Swipe your finger or type your password"
            color: root.lock.message !== "" ? Theme.error : Theme.on_surface_variant
            font.pixelSize: 15
        }

        // The fingerprint, as on Android's lock screen; red on a miss
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.lock.finger === "failed" ? root.shakeX : 0
            anchors.verticalCenter: undefined
            visible: root.lock.finger !== "off"
            name: "fingerprint"
            size: 44
            color: root.lock.finger === "failed" ? Theme.error : Theme.primary
        }
    }
}
