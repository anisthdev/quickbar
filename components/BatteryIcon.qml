import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "BatteryGlyphs.js" as Glyphs

// Port of Android 16's status bar battery (SystemUI UnifiedBattery.kt):
// a 24x13 body filled to the level with the percentage traced inside, and
// while charging, a bolt that replaces the cap and cuts into the body.
// Everything is laid out in Android's 24x13 viewport units, scaled by `s`.
Item {
    id: root

    property real percent: 100
    property bool charging: false
    // Status bar icon tint; Android uses white on dark backgrounds
    property color color: Theme.on_surface
    // Body height in pixels
    property real size: 14

    readonly property real s: size / 13
    readonly property int level: Math.max(0, Math.min(100, Math.round(percent)))
    readonly property bool full: level >= 100
    readonly property bool critical: !charging && level <= 20

    readonly property color tint: Qt.rgba(color.r, color.g, color.b, 1)
    readonly property color fillColor: charging ? "#18cc47" : critical ? "#ff0e01" : tint
    readonly property color bodyColor: full ? fillColor : Qt.rgba(tint.r, tint.g, tint.b, 0.55)
    readonly property color glyphColor: Theme.light ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(0, 0, 0, 0.75)

    // Digits laid out left to right, 0.8 units apart, centred in the body
    readonly property var digits: {
        const chars = String(level).split("");
        const width = chars.reduce((w, c) => w + Glyphs.glyphs[c].w, 0) + 0.8 * (chars.length - 1);
        let x = (24 - width) / 2;
        return chars.map(c => {
            const g = Glyphs.glyphs[c];
            const placed = {
                d: g.d,
                x: x,
                y: (13 - g.h) / 2
            };
            x += g.w + 0.8;
            return placed;
        });
    }

    // The bolt overlaps the body by 20% of its own width
    readonly property real boltX: 24 - Glyphs.glyphs.bolt.w * 0.2
    readonly property real boltY: (13 - Glyphs.glyphs.bolt.h) / 2

    implicitWidth: (charging ? boltX + Glyphs.glyphs.bolt.w : 24 + 1 + Glyphs.cap.w) * s
    implicitHeight: 13 * s
    anchors.verticalCenter: parent?.verticalCenter

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: battery

        anchors.fill: parent
        layer.enabled: root.charging
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cutout
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            id: body

            width: 24 * root.s
            height: 13 * root.s
            radius: 4 * root.s
            color: root.bodyColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animNormal
                }
            }

            // Fill: the full body shape clipped to the level, so it keeps the
            // rounded left end and gets a straight right edge
            Item {
                width: Math.ceil(root.level / 100 * 24) * root.s
                height: parent.height
                clip: true
                visible: !root.full

                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    width: body.width
                    height: body.height
                    radius: body.radius
                    color: root.fillColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animNormal
                        }
                    }
                }
            }

            Repeater {
                model: root.digits

                GlyphShape {
                    required property var modelData

                    unit: root.s
                    x: modelData.x * root.s
                    y: modelData.y * root.s
                    d: modelData.d
                    fill: root.glyphColor
                }
            }
        }

        GlyphShape {
            unit: root.s
            x: 25 * root.s
            y: (13 - Glyphs.cap.h) / 2 * root.s
            d: Glyphs.cap.d
            fill: root.bodyColor
            opacity: root.charging ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }

    // What the bolt cuts out of the body: the bolt plus a 2-unit outline
    Item {
        id: cutout

        anchors.fill: parent
        visible: false
        layer.enabled: true

        GlyphShape {
            unit: root.s
            x: root.boltX * root.s
            y: root.boltY * root.s
            d: Glyphs.glyphs.bolt.d
            fill: "white"
            stroke: "white"
            strokeWidth: 2
        }
    }

    // Sized wrapper so the bolt pops in from its centre
    Item {
        x: root.boltX * root.s
        y: root.boltY * root.s
        width: Glyphs.glyphs.bolt.w * root.s
        height: Glyphs.glyphs.bolt.h * root.s
        scale: root.charging ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.OutBack
            }
        }

        GlyphShape {
            unit: root.s
            d: Glyphs.glyphs.bolt.d
            fill: root.tint
        }
    }
}
