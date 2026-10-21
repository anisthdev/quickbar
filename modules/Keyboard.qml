import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

// The on-screen keyboard, after end-4's: a full US keyboard at the bottom
// of the screen, the function keys half height, with a column to pin it
// (windows then keep clear of it) and to hide it. It never takes the
// keyboard: keys go to the focused window through ydotool (its daemon,
// ydotoold, runs as a user service), as real key codes on a virtual
// keyboard, so shortcuts and Hyprland's binds see them as typed.
//
// Keys go down on press and up on release, so they repeat while held.
// Shift, Ctrl, Alt and Super stay down for the next key; a quick second
// tap keeps them down (Shift then is caps lock), a third lets go.
//
// The control panel opens it; so does `… ipc call osk toggle` (open,
// close).
Scope {
    id: root

    property bool open: false
    property bool pinned: false

    // 0 up, 1 down for the next key, 2 kept down
    property var mods: ({
            shift: 0,
            ctrl: 0,
            alt: 0,
            logo: 0
        })
    property var lastTap: ({})
    readonly property var modCodes: ({
            shift: 42,
            ctrl: 29,
            alt: 56,
            logo: 125
        })

    function toggle() {
        open = !open;
    }

    // Key events, "code:1" down and "code:0" up, sent in order: one
    // ydotool at a time, with whatever queued meanwhile
    property var queue: []

    function emit(code, down) {
        queue.push(`${code}:${down ? 1 : 0}`);
        flush();
    }

    function flush() {
        if (sender.running || queue.length === 0)
            return;
        sender.command = ["ydotool", "key", ...queue];
        queue = [];
        sender.running = true;
    }

    Process {
        id: sender

        onExited: root.flush()
    }

    function setMod(mod, state) {
        const next = Object.assign({}, mods);
        next[mod] = state;
        mods = next;
    }

    function tapMod(mod) {
        const now = Date.now();
        const quick = now - (lastTap[mod] ?? 0) < 300;
        lastTap[mod] = now;
        const state = mods[mod];
        const next = state === 0 ? 1 : state === 1 && quick ? 2 : 0;
        if (state === 0)
            emit(modCodes[mod], true);
        else if (next === 0)
            emit(modCodes[mod], false);
        setMod(mod, next);
    }

    function label(key) {
        if (mods.shift === 0)
            return key.l;
        return key.ls ?? key.l.toUpperCase();
    }

    function press(key) {
        emit(key.c, true);
    }

    // A key let go: so are the modifiers down just for it
    function release(key) {
        emit(key.c, false);
        const next = Object.assign({}, mods);
        for (const m in next) {
            if (next[m] === 1) {
                emit(modCodes[m], false);
                next[m] = 0;
            }
        }
        mods = next;
    }

    onOpenChanged: {
        if (open)
            return;
        for (const m in mods) {
            if (mods[m] > 0)
                emit(modCodes[m], false);
        }
        mods = {
            shift: 0,
            ctrl: 0,
            alt: 0,
            logo: 0
        };
    }

    // l: label (ls shifted), c: the evdev key code, w: width in keys,
    // fill: takes the row's spare width, mod: a modifier, gap: empty
    function keys(labels, codes) {
        return labels.split("").map((l, i) => ({
                    l: l,
                    c: codes + i
                }));
    }

    readonly property var rows: [
        [
            {
                l: "Esc",
                c: 1,
                fill: true
            },
            ...[59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88].map((c, i) => ({
                        l: `F${i + 1}`,
                        c: c,
                        fill: true
                    })),
            {
                l: "PrtSc",
                c: 99,
                fill: true
            },
            {
                l: "Del",
                c: 111,
                fill: true
            }
        ],
        [
            {
                l: "`",
                ls: "~",
                c: 41
            },
            ...["1!", "2@", "3#", "4$", "5%", "6^", "7&", "8*", "9(", "0)", "-_", "=+"].map((pair, i) => ({
                        l: pair[0],
                        ls: pair[1],
                        c: 2 + i
                    })),
            {
                icon: "backspace",
                c: 14,
                fill: true
            }
        ],
        [
            {
                l: "Tab",
                ls: "Tab",
                c: 15,
                w: 1.6
            },
            ...keys("qwertyuiop", 16),
            {
                l: "[",
                ls: "{",
                c: 26
            },
            {
                l: "]",
                ls: "}",
                c: 27
            },
            {
                l: "\\",
                ls: "|",
                c: 43,
                fill: true
            }
        ],
        [
            {
                gap: true,
                w: 1.9
            },
            ...keys("asdfghjkl", 30),
            {
                l: ";",
                ls: ":",
                c: 39
            },
            {
                l: "'",
                ls: "\"",
                c: 40
            },
            {
                icon: "subdirectory_arrow_left",
                c: 28,
                fill: true
            }
        ],
        [
            {
                l: "Shift",
                mod: "shift",
                w: 2.5
            },
            ...keys("zxcvbnm", 44),
            {
                l: ",",
                ls: "<",
                c: 51
            },
            {
                l: ".",
                ls: ">",
                c: 52
            },
            {
                l: "/",
                ls: "?",
                c: 53
            },
            {
                l: "Shift",
                mod: "shift",
                fill: true
            }
        ],
        [
            {
                l: "Ctrl",
                mod: "ctrl",
                w: 1.3
            },
            {
                l: "Super",
                mod: "logo",
                w: 1.3
            },
            {
                l: "Alt",
                mod: "alt",
                w: 1.3
            },
            {
                l: "",
                ls: "",
                c: 57,
                fill: true
            },
            {
                l: "Alt",
                mod: "alt",
                w: 1.3
            },
            {
                icon: "keyboard_arrow_left",
                c: 105
            },
            {
                icon: "keyboard_arrow_down",
                c: 108
            },
            {
                icon: "keyboard_arrow_up",
                c: 103
            },
            {
                icon: "keyboard_arrow_right",
                c: 106
            }
        ]
    ]

    readonly property real keySize: 45
    readonly property real gap: 5

    // Shown, 0 to 1: it rises from the bottom edge
    property real reveal: open ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: root.open ? 350 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.emphasizedDecel : Theme.emphasizedAccel
        }
    }

    PanelWindow {
        visible: root.open || root.reveal > 0
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: board.height + 20
        exclusionMode: root.pinned ? ExclusionMode.Auto : ExclusionMode.Ignore
        color: "transparent"
        // Never the keyboard: what's typed goes to the focused window
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        // Blurred behind, and animating itself
        WlrLayershell.namespace: "quickbar-overlay"
        mask: Region {
            item: board
        }

        Rectangle {
            id: board

            anchors.horizontalCenter: parent.horizontalCenter
            y: 10 + (1 - root.reveal) * (height + 20)
            width: content.implicitWidth + 20
            height: content.implicitHeight + 20
            radius: Theme.radius * 2
            color: Theme.background
            opacity: root.reveal

            RowLayout {
                id: content

                anchors.centerIn: parent
                spacing: root.gap

                // Pin (windows keep clear of it) and hide
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: root.gap

                    ControlButton {
                        icon: "keep"
                        toggled: root.pinned
                        onClicked: root.pinned = !root.pinned
                    }

                    ControlButton {
                        icon: "keyboard_hide"
                        onClicked: root.open = false
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 20
                    Layout.bottomMargin: 20
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    implicitWidth: 1
                    color: Theme.outline
                    opacity: 0.4
                }

                ColumnLayout {
                    spacing: root.gap

                    Repeater {
                        model: root.rows

                        RowLayout {
                            id: row

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: root.gap

                            Repeater {
                                model: row.modelData

                                Key {
                                    required property var modelData

                                    osk: root
                                    key: modelData
                                    short: row.index === 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ControlButton: Rectangle {
        id: control

        property string icon
        property bool toggled: false

        signal clicked

        implicitWidth: 40
        implicitHeight: 40
        radius: Theme.radius
        color: toggled ? Theme.primary : Theme.surface_container_high

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Icon {
            anchors.centerIn: parent
            name: control.icon
            size: 20
            color: control.toggled ? Theme.on_primary : Theme.on_surface
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.on_surface
            opacity: controlMouse.pressed ? 0.12 : controlMouse.containsMouse ? 0.08 : 0
        }

        MouseArea {
            id: controlMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    // One key: down while pressed; a modifier stays down for the next
    component Key: Rectangle {
        id: keyItem

        // Inline components don't see root
        required property var osk
        required property var key
        // The function row's, half height
        property bool short: false
        readonly property bool toggled: key.mod ? keyItem.osk.mods[key.mod] > 0 : false

        Layout.fillWidth: key.fill ?? false
        implicitWidth: keyItem.osk.keySize * (key.w ?? 1) + keyItem.osk.gap * ((key.w ?? 1) - 1)
        implicitHeight: short ? keyItem.osk.keySize * 0.7 : keyItem.osk.keySize
        radius: Theme.radius * 0.8
        color: key.gap ? "transparent" : toggled ? Theme.primary : Theme.surface_container_high
        // Locked: a ring as well
        border.width: key.mod && keyItem.osk.mods[key.mod] === 2 ? 2 : 0
        border.color: Theme.on_primary

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        Label {
            anchors.centerIn: parent
            visible: !keyItem.key.icon
            text: keyItem.key.gap || keyItem.key.icon ? "" : keyItem.osk.label(keyItem.key)
            color: keyItem.toggled ? Theme.on_primary : Theme.on_surface
            font.pixelSize: keyItem.short ? 12 : keyItem.key.mod || (keyItem.key.l?.length ?? 0) > 1 ? 13 : 16
        }

        Icon {
            anchors.centerIn: parent
            visible: !!keyItem.key.icon
            name: keyItem.key.icon ?? ""
            size: 20
            color: Theme.on_surface
        }

        Rectangle {
            anchors.fill: parent
            visible: !keyItem.key.gap
            radius: parent.radius
            color: Theme.on_surface
            opacity: keyMouse.pressed ? 0.16 : keyMouse.containsMouse ? 0.06 : 0
        }

        MouseArea {
            id: keyMouse

            anchors.fill: parent
            enabled: !keyItem.key.gap
            hoverEnabled: true
            onPressed: {
                if (keyItem.key.mod)
                    keyItem.osk.tapMod(keyItem.key.mod);
                else
                    keyItem.osk.press(keyItem.key);
            }
            onReleased: {
                if (!keyItem.key.mod)
                    keyItem.osk.release(keyItem.key);
            }
            onCanceled: {
                if (!keyItem.key.mod)
                    keyItem.osk.release(keyItem.key);
            }
        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }
}
