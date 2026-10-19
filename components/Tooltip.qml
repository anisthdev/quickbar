import Quickshell
import QtQuick
import ".."

// Material 3 plain tooltip below a bar item, in the dark surface colours
// the menus use rather than M3's inverted ones. Appears after a short hover
// delay, and leaves as soon as `shown` turns off.
PopupWindow {
    id: root

    required property Item owner
    property bool shown: false
    property string text

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
    implicitWidth: Math.ceil(label.implicitWidth) + 24
    implicitHeight: 28
    color: "transparent"
    visible: active || bubble.opacity > 0

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
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.9
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? Theme.animFast : 100
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasizedDecel
            }
        }

        Label {
            id: label

            anchors.centerIn: parent
            text: root.text
            color: Theme.on_surface
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
