import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import ".."

// A Material 3 style menu that drops down from a bar item. The container
// springs open from the top with a little overshoot while its entries
// fade in one after another (see MenuReveal); closing is quicker and
// accelerates away. Closes on a click anywhere else or on Escape.
// Content goes in as children and sets the height; `menuWidth` the width.
PopupWindow {
    id: root

    required property Item owner
    property bool open: false
    property real menuWidth: 300
    default property alias content: column.data

    // Room around the panel for its shadow, and below it for the overshoot
    readonly property real shadowPad: 32
    readonly property real topPad: 8
    readonly property real fullHeight: column.implicitHeight + 2 * column.anchors.topMargin

    // 0 = folded, 1 = open; overshoots past 1 while springing open
    property real reveal: 0

    // A click on the owner while open first clears the focus grab (closing
    // the menu) and then reaches the owner, which would reopen it. The owner
    // checks this to make that click close the menu instead.
    property double closedAt: 0

    // Centred under the owner, but kept inside the bar window so the menu
    // lines up with the bar's edge instead of running off screen
    property real offsetX: 0

    function toggle() {
        if (!open) {
            const bar = owner.QsWindow.window;
            const ownerX = owner.mapToItem(null, 0, 0).x;
            const x = Math.max(0, Math.min(bar.width - menuWidth, ownerX + owner.width / 2 - menuWidth / 2));
            offsetX = x - ownerX;
        }
        open = !open && Date.now() - closedAt > 250;
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.start();
        } else {
            closedAt = Date.now();
            openAnim.stop();
            closeAnim.start();
        }
    }

    anchor.item: owner
    anchor.rect.x: offsetX - shadowPad
    anchor.rect.y: owner.height + 8 - topPad
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    implicitWidth: menuWidth + 2 * shadowPad
    implicitHeight: topPad + fullHeight * 1.15 + shadowPad
    color: "transparent"
    // Stay mapped until the closing animation finishes
    visible: open || closeAnim.running

    HyprlandFocusGrab {
        windows: [root]
        active: root.open
        onCleared: root.open = false
    }

    ParallelAnimation {
        id: openAnim

        // Spatial: springs past full height and settles back
        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: 500
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.92
            to: 1
            duration: 400
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        // Effects: a quick fade, no bounce
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 120
        }
    }

    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0.4
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 0.96
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }
    }

    // The transparent margin is part of this window, so the focus grab
    // doesn't see clicks there; close on them here instead
    MouseArea {
        anchors.fill: parent
        onClicked: root.open = false
    }

    RectangularShadow {
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height
        radius: panel.radius
        offset.y: 4
        blur: 24
        // Under Hyprland's popups_ignorealpha (0.2) everywhere, or the
        // darker part of the shadow gets blurred into a grainy strip
        color: Qt.rgba(0, 0, 0, 0.19)
        opacity: panel.opacity
        scale: panel.scale
        transformOrigin: Item.Top
    }

    Rectangle {
        id: panel

        x: root.shadowPad
        y: root.topPad
        width: root.menuWidth
        height: root.fullHeight * (0.4 + 0.6 * root.reveal)
        radius: 24
        color: Theme.surface_container
        clip: true
        opacity: 0
        transformOrigin: Item.Top
        focus: root.open
        Keys.onEscapePressed: root.open = false

        // Swallow clicks on the panel's own background
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 12
            spacing: 4
        }
    }
}
