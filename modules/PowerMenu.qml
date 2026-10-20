import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."
import "../components"

// The power menu, in power-menu's place (bottom centre, one row): lock,
// suspend, hibernate, restart and power off as big tiles, a grouped list
// on its side with the pick's fill sliding between them. It springs open
// upwards like the other menus.
//
// Keys: h/l (or the arrows, Tab) move, 0/^ and $ (or gg/G) go to the
// ends, 1-5 pick directly, Enter or Space runs, q or Esc closes. The
// choice runs once the menu has folded away, so a lock screen or a
// suspend never freezes it half drawn.
Scope {
    id: root

    property bool open: false
    property int current: 0
    // The choice waiting for the menu to go
    property var pending: null

    readonly property var actions: [
        {
            label: "Lock",
            icon: "lock_screen",
            command: ["sh", "-c", "pidof hyprlock || systemd-cat -t hyprlock hyprlock"]
        },
        {
            label: "Suspend",
            icon: "bedtime",
            command: ["sh", "-c", "mpc -q pause; systemctl suspend"]
        },
        {
            label: "Hibernate",
            icon: "ac_unit",
            command: ["systemctl", "hibernate"]
        },
        {
            label: "Restart",
            icon: "restart",
            command: ["systemctl", "reboot"]
        },
        {
            label: "Power off",
            icon: "power_off",
            command: ["systemctl", "poweroff"]
        }
    ]

    function show() {
        current = 0;
        pending = null;
        open = true;
        keys.forceActiveFocus();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    function move(by) {
        current = Math.max(0, Math.min(actions.length - 1, current + by));
    }

    function run(index) {
        if (!actions[index])
            return;
        pending = actions[index];
        hide();
    }

    PanelWindow {
        id: window

        property real reveal: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Mapped from opening until the fold-away has finished
        visible: false
        // Blurred, without Hyprland's layer slide (see looknfeel.lua)
        WlrLayershell.namespace: "quickbar-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    closeAnim.stop();
                    window.visible = true;
                    openAnim.restart();
                } else {
                    openAnim.stop();
                    closeAnim.restart();
                }
            }
        }

        // Gone from the screen first: a frame later the compositor has
        // dropped it too
        onVisibleChanged: if (!visible && root.pending)
            runLater.restart()

        Timer {
            id: runLater

            interval: 100
            onTriggered: {
                Quickshell.execDetached(root.pending.command);
                root.pending = null;
            }
        }

        NumberAnimation {
            id: openAnim

            target: window
            property: "reveal"
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }

        NumberAnimation {
            id: closeAnim

            target: window
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
            onFinished: window.visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: panel

            readonly property real fullHeight: row.height + 2 * row.y

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: row.width + 2 * row.x
            height: Math.max(0, fullHeight * window.reveal)
            radius: Theme.cardRadius
            color: Theme.surface_container
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keys

                // The first g of a gg
                property bool pendingG: false

                Timer {
                    id: gTimer

                    interval: 600
                    onTriggered: keys.pendingG = false
                }

                Keys.onPressed: event => {
                    const g = event.key === Qt.Key_G && event.text === "g";
                    if (!g)
                        pendingG = false;
                    if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.actions.length) {
                        root.run(event.key - Qt.Key_1);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_H:
                    case Qt.Key_Left:
                    case Qt.Key_Backtab:
                        root.move(-1);
                        break;
                    case Qt.Key_L:
                    case Qt.Key_Right:
                    case Qt.Key_Tab:
                        root.move(1);
                        break;
                    case Qt.Key_0:
                    case Qt.Key_AsciiCircum:
                    case Qt.Key_Home:
                        root.current = 0;
                        break;
                    case Qt.Key_Dollar:
                    case Qt.Key_End:
                        root.current = root.actions.length - 1;
                        break;
                    case Qt.Key_G:
                        // A capital can come without Shift held (wtype)
                        if (event.text === "G") {
                            root.current = root.actions.length - 1;
                        } else if (pendingG) {
                            pendingG = false;
                            root.current = 0;
                        } else {
                            pendingG = true;
                            gTimer.restart();
                        }
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.run(root.current);
                        break;
                    case Qt.Key_Escape:
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }

            // The grouped list of the other menus, laid on its side: the
            // pick's fill slides from tile to tile above the tiles'
            // backgrounds (on a layer of their own, below) and under their
            // icons and labels
            ListView {
                id: row

                x: 18
                y: 18
                width: contentWidth
                height: 96
                orientation: ListView.Horizontal
                spacing: 2
                interactive: false
                currentIndex: root.current
                model: root.actions
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 220
                highlightMoveVelocity: -1
                highlight: Rectangle {
                    radius: Theme.radius
                    color: Theme.secondary_container
                    // Fades in with its tile as the menu opens
                    opacity: row.currentItem?.opacity ?? 1
                }

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: ListView.isCurrentItem
                    // Grouped corners, as the lists' rows have them on top
                    // and bottom
                    readonly property real leftCorners: index === 0 ? Theme.radius : 3
                    readonly property real rightCorners: index === row.count - 1 ? Theme.radius : 3

                    width: 92
                    height: row.height

                    // The tile's background, moved under the list's
                    // highlight; it follows the tile, fading in with it
                    Rectangle {
                        parent: row.contentItem
                        z: -1
                        x: tile.x
                        y: tile.y
                        width: tile.width
                        height: tile.height
                        topLeftRadius: tile.leftCorners
                        bottomLeftRadius: tile.leftCorners
                        topRightRadius: tile.rightCorners
                        bottomRightRadius: tile.rightCorners
                        color: hover.containsMouse && !tile.isCurrent ? Theme.surface_container_highest : Theme.surface_container_high
                        opacity: tile.opacity
                    }

                    // A fixed box for every icon, so they all sit on the
                    // tile's centre line whatever their width
                    Item {
                        id: glyph

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.verticalCenter
                        anchors.bottomMargin: -2
                        width: 28
                        height: 28

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: tile.modelData.icon
                            size: 28
                            color: tile.isCurrent ? Theme.on_secondary_container : Theme.on_surface
                        }
                    }

                    Label {
                        anchors.verticalCenter: undefined
                        anchors.top: glyph.bottom
                        anchors.topMargin: 8
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.label
                        color: tile.isCurrent ? Theme.on_secondary_container : Theme.on_surface_variant
                        font.pixelSize: 14
                    }

                    // Staggered in like the other menus' rows
                    MenuReveal {
                        target: tile
                        shown: root.open
                        index: tile.index
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = tile.index
                        onClicked: root.run(tile.index)
                    }
                }
            }
        }
    }

    // `qs -p <dir> ipc call power toggle`, e.g. from Super+Escape
    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }
    }
}
