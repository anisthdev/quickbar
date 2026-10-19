import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import ".."
import "../components"

// Tray apps, Android style: up to `pinnedCount` icons stay visible and the
// rest fold behind a chevron. Apps that say they're idle (Passive) always
// fold. Clicking the chevron springs the hidden icons out; they fold back
// a moment after the cursor leaves the tray, unless one of their menus is
// open.
Pill {
    id: root

    readonly property int pinnedCount: 4
    readonly property var items: SystemTray.items.values
    readonly property var active: items.filter(i => i.status !== Status.Passive)
    readonly property var pinned: active.slice(0, pinnedCount)
    readonly property var overflow: items.filter(i => !pinned.includes(i))
    property bool expanded: false
    readonly property bool overflowNeedsAttention: overflow.some(i => i.status === Status.NeedsAttention)

    function anyOverflowMenuOpen() {
        for (let i = 0; i < overflowButtons.count; i++) {
            if (overflowButtons.itemAt(i)?.menuOpen)
                return true;
        }
        return false;
    }

    padding: 4
    spacing: 0
    // The buttons and chevron animate their own widths
    animateWidth: false
    color: Theme.tertiary_container
    visible: items.length > 0

    onOverflowChanged: if (overflow.length === 0)
        expanded = false

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered)
                collapseTimer.stop();
            else if (root.expanded)
                collapseTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: 2500
        onTriggered: {
            if (root.anyOverflowMenuOpen())
                restart();
            else
                root.expanded = false;
        }
    }

    Repeater {
        id: overflowButtons

        model: ScriptModel {
            values: root.overflow
        }

        TrayButton {
            required property SystemTrayItem modelData

            item: modelData
            folded: !root.expanded
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.pinned
        }

        TrayButton {
            required property SystemTrayItem modelData

            item: modelData
        }
    }

    // Overflow chevron, at the right end so that it and the pinned icons
    // stay put while hidden icons unfold at the left. Points left to unfold,
    // turns to fold back.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: root.overflow.length > 0 ? 26 : 0
        height: 30
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: 13
            color: Theme.on_tertiary_container
            opacity: chevronMouse.pressed ? 0.16 : chevronMouse.containsMouse ? 0.10 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "chevron"
            size: 14
            color: Theme.on_tertiary_container
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasizedDecel
                }
            }
        }

        // A folded app wants attention
        Badge {
            x: 17
            y: 5
            shown: root.overflowNeedsAttention && !root.expanded
        }

        MouseArea {
            id: chevronMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
}
