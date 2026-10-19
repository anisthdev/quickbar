import Quickshell.Hyprland
import QtQuick
import ".."
import "../components"

// Workspaces as a row of rounded slots. Occupied ones show their number and
// run together into one tonal pill with their occupied neighbours; empty
// ones are a small dot. The active one is a filled pill that travels
// between slots, its leading edge first so it stretches and snaps, as
// Material 3 Expressive tab indicators do. Scroll to step through them.
Pill {
    id: root

    // Always show 1-8, plus any higher workspace that currently exists
    readonly property int count: Math.max(8, HyprState.maxId)
    readonly property int activeIndex: HyprState.focusedId - 1

    readonly property real slotHeight: Theme.barHeight - 10
    readonly property real slotWidth: 34
    // The active pill and hover highlight span the whole slot
    readonly property real pillWidth: slotWidth
    // The bar's corner radius scaled to the slots, so they're the same
    // shape as the pill around them
    readonly property real cornerRadius: Theme.radius * slotHeight / Theme.barHeight

    function occupied(i) {
        return i >= 0 && i < count && HyprState.windows(i + 1) > 0;
    }

    function focus(target) {
        // Hyprland's Lua config takes dispatchers as Lua expressions
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${typeof target === "string" ? `"${target}"` : target} })`);
    }

    // The indicator is a pill centred in the active slot; its two edges
    // animate separately for the stretch
    function circleLeft(i) {
        return i * slotWidth + (slotWidth - pillWidth) / 2;
    }

    property real indicatorLeft: circleLeft(activeIndex)
    property real indicatorRight: indicatorLeft + pillWidth

    onActiveIndexChanged: {
        const left = circleLeft(activeIndex);
        const forward = left > indicatorLeft;
        // The edge facing the direction of travel leads
        leftEdge.duration = forward ? 380 : 200;
        rightEdge.duration = forward ? 200 : 380;
        leftEdge.to = left;
        rightEdge.to = left + pillWidth;
        stretch.restart();
    }

    padding: 5
    spacing: 0

    ParallelAnimation {
        id: stretch

        NumberAnimation {
            id: leftEdge

            target: root
            property: "indicatorLeft"
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
        NumberAnimation {
            id: rightEdge

            target: root
            property: "indicatorRight"
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasizedDecel
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: root.count * root.slotWidth
        height: root.slotHeight

        // Scroll to step through workspaces; trackpads send many small
        // deltas, so step once per full wheel notch's worth
        WheelHandler {
            property real pending: 0

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                pending += event.angleDelta.y;
                while (Math.abs(pending) >= 120) {
                    root.focus(pending > 0 ? "e-1" : "e+1");
                    pending -= Math.sign(pending) * 120;
                }
            }
        }

        // Occupied backgrounds. Each slot squares off the side it shares
        // with an occupied neighbour, so runs read as one pill and join or
        // split smoothly as windows come and go.
        Repeater {
            model: root.count

            Rectangle {
                id: fill

                required property int index
                readonly property bool here: root.occupied(index)
                readonly property bool urgent: HyprState.workspaces[index + 1]?.urgent ?? false
                readonly property real round: root.cornerRadius
                property real leftCorners: root.occupied(index - 1) ? 0 : round
                property real rightCorners: root.occupied(index + 1) ? 0 : round

                x: index * root.slotWidth
                width: root.slotWidth
                height: root.slotHeight
                topLeftRadius: leftCorners
                bottomLeftRadius: leftCorners
                topRightRadius: rightCorners
                bottomRightRadius: rightCorners
                color: urgent ? Theme.error : Theme.surface_container_highest
                opacity: here || urgent ? 1 : 0

                Behavior on leftCorners {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on rightCorners {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animNormal
                    }
                }
            }
        }

        // Hover state layers and clicks
        Repeater {
            model: root.count

            Item {
                id: slot

                required property int index

                x: index * root.slotWidth
                width: root.slotWidth
                height: root.slotHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.pillWidth
                    height: root.slotHeight
                    radius: root.cornerRadius
                    color: Theme.on_surface
                    opacity: mouse.pressed ? 0.12 : mouse.containsMouse && slot.index !== root.activeIndex ? 0.08 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focus(slot.index + 1)
                }
            }
        }

        Rectangle {
            id: indicator

            x: root.indicatorLeft
            width: root.indicatorRight - root.indicatorLeft
            height: root.slotHeight
            radius: root.cornerRadius
            // Same as the active status buttons on the right of the bar
            color: Theme.primary_container
        }

        // Numbers for occupied workspaces, dots for empty ones; drawn over
        // the indicator, in its colours when it sits under them
        Repeater {
            model: root.count

            Item {
                id: mark

                required property int index
                readonly property bool active: index === root.activeIndex
                readonly property bool here: root.occupied(index)
                readonly property bool urgent: HyprState.workspaces[index + 1]?.urgent ?? false
                readonly property color ink: active ? Theme.on_primary_container : urgent ? Theme.on_error : here ? Theme.on_surface : Theme.outline

                x: index * root.slotWidth
                width: root.slotWidth
                height: root.slotHeight

                Label {
                    anchors.centerIn: parent
                    text: mark.index + 1
                    color: mark.ink
                    font.weight: mark.active ? Font.Bold : Font.Medium
                    opacity: mark.here ? 1 : 0
                    scale: mark.here ? 1 : 0.5

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animNormal
                            easing.type: Easing.OutBack
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 5
                    height: 5
                    radius: 2.5
                    color: mark.ink
                    opacity: mark.here ? 0 : 1
                    scale: mark.here ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animNormal
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }
    }
}
