import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import ".."

// A Material 3 style menu that drops down from a bar item. The container
// springs open from the top with a little overshoot while its entries
// fade in one after another (see MenuReveal); closing folds it back up,
// quicker and accelerating away. Closes on a click anywhere else or on
// Escape. Content goes in as children and sets the height; `menuWidth`
// the width.
//
// The container's shape animates but its opacity never does: Hyprland
// blurs a pixel fully or not at all, so a fading panel would leave a
// blurred empty box behind until it crossed the blur threshold. A solid
// panel changing size takes its blur along with it.
PopupWindow {
    id: root

    required property Item owner
    property bool open: false
    property real menuWidth: 300
    // A large title over the content, as Android's quick settings dialogs have
    property string title
    default property alias content: column.data

    // Room around the content; roomy by default, as for the quick settings
    // style menus, tighter where a compact menu suits better
    property real sidePadding: 20
    property real endPadding: 18
    property real cornerRadius: Theme.cardRadius

    // Room around the panel for its shadow, and below it for the overshoot
    readonly property real shadowPad: 32
    readonly property real topPad: 8
    readonly property real fullHeight: column.implicitHeight + 2 * endPadding

    // 0 = folded away, 1 = open; overshoots past 1 while springing open
    property real reveal: 0

    // Ease between content heights while open (e.g. switching pages)
    // rather than jumping. Off where the content animates its own height.
    property bool smoothResize: false
    property real contentHeight: fullHeight

    Behavior on contentHeight {
        enabled: root.smoothResize && root.open && !openAnim.running && !closeAnim.running
        NumberAnimation {
            duration: 250
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

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
    // Tall enough for the content before and after a resize
    implicitHeight: topPad + Math.max(fullHeight, contentHeight) * 1.15 + shadowPad
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
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.92
            to: 1
            duration: 250
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 0.96
            duration: 150
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedAccel
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
        scale: panel.scale
        transformOrigin: Item.Top
    }

    Rectangle {
        id: panel

        x: root.shadowPad
        y: root.topPad
        width: root.menuWidth
        height: root.contentHeight * root.reveal
        radius: Math.min(root.cornerRadius, height / 2)
        color: Theme.surface_container
        clip: true
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
            anchors.leftMargin: root.sidePadding
            anchors.rightMargin: root.sidePadding
            anchors.topMargin: root.endPadding
            spacing: 4

            Label {
                id: titleLabel

                anchors.verticalCenter: undefined
                visible: root.title !== ""
                leftPadding: 8
                bottomPadding: 10
                text: root.title
                color: Theme.on_surface
                font.pixelSize: 24
                font.weight: Font.Normal

                MenuReveal {
                    target: titleLabel
                    shown: root.open
                }
            }
        }
    }
}
