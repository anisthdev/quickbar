import Quickshell
import QtQuick
import ".."

// Material 3 plain tooltip below a bar item, in the dark surface colours
// the menus use rather than M3's inverted ones. An optional `description`
// adds a second, quieter line. Appears after a short hover delay, and
// leaves as soon as `shown` turns off.
PopupWindow {
    id: root

    required property Item owner
    property bool shown: false
    property string text
    property string description

    // Hover has to settle for this long before the tooltip appears
    property int delay: 500
    property bool active: false

    onShownChanged: {
        if (shown) {
            delayTimer.restart();
        } else {
            delayTimer.stop();
            active = false;
        }
    }

    anchor.item: owner
    anchor.rect.x: owner.width / 2
    anchor.rect.y: owner.height + 6
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Bottom
    implicitWidth: Math.ceil(lines.implicitWidth) + 24
    implicitHeight: Math.ceil(lines.implicitHeight) + 12
    color: "transparent"
    visible: active || bubble.scale > 0

    Timer {
        id: delayTimer
        interval: root.delay
        onTriggered: root.active = root.text !== ""
    }

    Rectangle {
        id: bubble

        anchors.fill: parent
        radius: 8
        color: Theme.surface_container_high
        // Grows and shrinks rather than fading, so Hyprland's blur follows
        // its shape instead of lingering (see Dropdown)
        scale: root.active ? 1 : 0
        transformOrigin: Item.Top

        Behavior on scale {
            NumberAnimation {
                duration: root.active ? 180 : 120
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.active ? Theme.emphasizedDecel : Theme.emphasizedAccel
            }
        }

        Column {
            id: lines

            anchors.centerIn: parent
            spacing: 1

            Label {
                anchors.verticalCenter: undefined
                text: root.text
                color: Theme.on_surface
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Label {
                anchors.verticalCenter: undefined
                visible: text !== ""
                // Some apps send rich-text markup here
                text: root.description.replace(/<[^>]*>/g, "").trim()
                color: Theme.on_surface_variant
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
