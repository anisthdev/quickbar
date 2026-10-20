import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

// A menu of a few big choices in one row, in the rofi small menus' place
// (bottom centre): the power menu, the screenshot and screen record ones.
// The tiles are a grouped list on its side, with the pick's fill sliding
// between them, and the menu springs open upwards like the others; an
// optional title sits above them.
//
// Keys: h/l (or the arrows, Tab) move, 0/^ and $ (or gg/G) go to the
// ends, 1-9 pick directly, Enter or Space runs, q or Esc closes. Opened
// from another menu (show(true)), a back arrow shows by the title, and it,
// Backspace or Esc emit `back` once the menu has gone. The
// choice runs once the menu has folded away, so a lock screen, a suspend
// or a screenshot never catches it half drawn.
Scope {
    id: root

    property bool open: false
    property int current: 0
    // The choice waiting for the menu to go
    property var pending: null

    property string title
    // [{ label, icon, command }, …]: icon a theme icon name, command an argv
    property var entries: []
    // Opened from another menu, which `back` returns to
    property bool canGoBack: false
    property bool goingBack: false

    // After the menu has gone and the entry's command (if any) has run
    signal activated(var entry)
    signal back

    function show(fromMenu) {
        current = 0;
        pending = null;
        goingBack = false;
        canGoBack = !!fromMenu;
        open = true;
        keys.forceActiveFocus();
    }

    function goBack() {
        goingBack = true;
        hide();
    }

    function hide() {
        open = false;
    }

    function toggle() {
        open ? hide() : show();
    }

    function move(by) {
        current = Math.max(0, Math.min(entries.length - 1, current + by));
    }

    function run(index) {
        if (!entries[index])
            return;
        pending = entries[index];
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
        onVisibleChanged: {
            if (visible)
                return;
            if (root.pending)
                runLater.restart();
            else if (root.goingBack) {
                root.goingBack = false;
                root.back();
            }
        }

        Timer {
            id: runLater

            interval: 100
            onTriggered: {
                const entry = root.pending;
                root.pending = null;
                if (entry.command)
                    Quickshell.execDetached(entry.command);
                root.activated(entry);
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

            readonly property real fullHeight: row.y + row.height + 18

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
                    if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.entries.length) {
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
                        root.current = root.entries.length - 1;
                        break;
                    case Qt.Key_G:
                        // A capital can come without Shift held (wtype)
                        if (event.text === "G") {
                            root.current = root.entries.length - 1;
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
                    case Qt.Key_Backspace:
                        if (!root.canGoBack)
                            return;
                        root.goBack();
                        break;
                    case Qt.Key_Escape:
                        root.canGoBack ? root.goBack() : root.hide();
                        break;
                    case Qt.Key_Q:
                        root.hide();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }
            }

            Row {
                id: titleLabel

                visible: root.title !== ""
                x: 20
                y: 22
                height: 34
                spacing: 4

                IconButton {
                    visible: root.canGoBack
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron"
                    iconSize: 22
                    color: Theme.primary
                    onClicked: root.goBack()
                }

                Label {
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    text: root.title
                    color: Theme.primary
                    font.pixelSize: 26
                    font.weight: Theme.titleWeight
                    roundness: Theme.titleRoundness
                }
            }

            // The grouped list of the other menus, laid on its side: the
            // pick's fill slides from tile to tile above the tiles'
            // backgrounds (on a layer of their own, below) and under their
            // icons and labels
            ListView {
                id: row

                x: 18
                y: titleLabel.visible ? titleLabel.y + titleLabel.height + 14 : 18
                width: contentWidth
                height: 96
                orientation: ListView.Horizontal
                spacing: 2
                interactive: false
                currentIndex: root.current
                model: root.entries
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
                        width: 36
                        height: 36

                        IconImage {
                            anchors.fill: parent
                            source: Quickshell.iconPath(tile.modelData.icon, true)
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
}
